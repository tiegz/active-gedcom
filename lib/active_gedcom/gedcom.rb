require 'yaml'

module ActiveGedcom
  class Gedcom
    attr_accessor :charset, :source
    attr_accessor :people, :families

    def initialize(gedcom_filename)
      file = File.open(gedcom_filename).read

      yaml = gedcom_to_yaml(file) + "\n"
      @json = YAML.load(yaml)
      @people = {}
      @families = {}

      parse_head(@json.delete 'HEAD')

      @json.each_pair do |k,v|
        if k == 'HEAD'
          parse_head(v)
        elsif v.nil?
          # ?
        elsif v['VALUE'] == "INDI"
          parse_person(k, v)
        elsif v['VALUE'] == "FAM"
          parse_family(k, v)
        end
      end

      link_people_to_families
    end

    def parse_head(head)
      @charset = head['CHAR']['VALUE']
      @source = head['SOUR']
    end

    def parse_family(k, v)
      @families[k] ||= Family.new(k)

      @families[k].husband  = @people[v['HUSB']['VALUE']] rescue nil
      @families[k].wife     = @people[v['WIFE']['VALUE']] rescue nil
      # TODO This is only 1 value in my gedcom... is it ever more, if you have linked siblings??
      @families[k].children <<  @people[v['CHIL']['VALUE']]
    end

    def parse_person(k, v)
      @people[k] ||= Person.new(k)

      @people[k].name       = v['NAME']['VALUE'] rescue nil
      @people[k].sex        = v['SEX']['VALUE'] rescue nil
      @people[k].birth      = v['BIRT']['DATE']['VALUE'] rescue nil
      @people[k].birthplace = v['BIRT']['PLAC']['VALUE'] rescue nil
      @people[k].death      = v['DEAT']['DATE']['VALUE'] rescue nil
      @people[k].deathplace = v['DEAT']['PLAC']['VALUE'] rescue nil
      @people[k].famc       = v['FAMC']['VALUE'] rescue nil
      @people[k].fams       = v['FAMS']['VALUE'] rescue nil
    end

    def link_people_to_families
      @people.each_pair do |id,person|
        if famc = @families[person.famc]
          @people[id].famc = famc
        end
        if fams = @families[person.fams]
          @people[id].fams = fams
        end
      end
    end

    def direct!
      direct_person_ids = []
      recurse_family(people.values.first) do |person, level|
        direct_person_ids << person.id
      end

      people.delete_if { |id, person| !direct_person_ids.include?(id) }
    end

    def to_text
      lines = []
      recurse_family(people.values.first) do |person, level|
        lines << "#{'  ' * level}#{person.name}"
      end
      lines.join("\n")
    end

    def to_dot
      dot = "digraph \"gedcom\" {\n"

      root_person = people.values.first

      years = []
      people_ids = []

      dot << "#{root_person.id.inspect} [shape=box label=#{root_person.birthyear.inspect}]"
      years << root_person.birthyear
      people_ids << root_person.id

      dot << "node [shape=box];\n"
      people.values.each do |person|
        dot << "#{person.id.inspect} [label=#{[person.name, "#{[person.birthyear, person.deathyear].compact.join(" - ")}"].join("\n").inspect}];\n"
        if mother = person.mother
          dot << "{ rank = same; #{mother.birthyear}; #{mother.id.inspect} }\n" if mother.birthyear
          dot << "#{mother.id.inspect} -> #{person.id.inspect} [label=\"♀\"];\n"
          years << mother.birthyear
          people_ids << mother.id
        end
        if father = person.father
          dot << "{ rank = same; #{father.birthyear}; #{father.id.inspect} }\n" if father.birthyear
          dot << "#{father.id.inspect} -> #{person.id.inspect} [label=\"♂\"];\n"
          years << father.birthyear
          people_ids << father.id
        end
      end

      # Year labels
      years = years.uniq.compact.sort
      first_year = years.shift
      last_year = years.pop
      dot << "{\n"
      dot << "node [shape=plaintext, fontsize=16];\n"
      dot << "#{first_year} -> #{years.join(' -> ')} -> #{last_year};\n" # Timeline
      dot << "#{people_ids.map(&:inspect).join(";")};\n" # Ancestors
      dot << "}\n"

      dot << "}\n"
      dot
    end

    def recurse_family(person, level=0, &blk)
      yield person, level
      recurse_family(person.mother, level + 1, &blk) if person.mother
      recurse_family(person.father, level + 1, &blk) if person.father
    end

    private

    # GEDCOM is very transformable to yaml, with one exception: a node can have
    # both a value *and* children (like XML). So we transform it to YAML syntax,
    # and add a child "VALUE" line if there's a value for the node.
    def gedcom_to_yaml(f)
      yaml = "---\n"
      lines = f.lines
      line = lines.shift

      while line
        level, key, val = line.split(" ", 3).map(&:strip)
        level = level.to_i

        yaml << "#{'  ' * level}#{key.inspect}: #{val.inspect if key == 'VALUE'}\n"

        if val.size.zero? || key == 'VALUE'
          line = lines.shift
        else
          line = "#{level + 1} VALUE #{val}"
        end
      end
      yaml
    end
  end
end
