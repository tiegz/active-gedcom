require 'yaml'

class Gedcom
  attr_accessor :charset, :source
  attr_accessor :people, :families

  class Family
    attr_accessor :children, :wife, :husband
    def initialize(id)
      @id = id
      @children = []
    end
  end

  class Person
    attr_accessor :id, :name, :sex, :birth, :death, :mother, :father, :famc, :fams, :birthplace, :deathplace
    def initialize(id)
      @id = id
    end
    def mother; famc.wife if famc; end
    def father; famc.husband if famc; end
  end

  def initialize(file)
    file = File.open(ARGV[0]).read
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
    ensure_people_families
  end

  def parse_head(head)
    @charset = head['CHAR']['VALUE']
    @source = head['SOUR']
  end

  def parse_family(k, v)
    @families[k] ||= Family.new(k)
    @families[k].husband = @people[v['HUSB']['VALUE']] rescue nil
    @families[k].wife = @people[v['WIFE']['VALUE']] rescue nil
    # TODO This is only 1 value in my gedcom... is it ever more, if you have linked siblings??
    @families[k].children <<  @people[v['CHIL']['VALUE']]
  end

  def parse_person(k, v)
    @people[k] ||= Person.new(k)
    @people[k].name = v['NAME']['VALUE'] rescue nil
    @people[k].sex = v['SEX']['VALUE'] rescue nil
    @people[k].birth = v['BIRT']['DATE']['VALUE'] rescue nil
    @people[k].birthplace = v['BIRT']['PLAC']['VALUE'] rescue nil
    @people[k].death = v['DEAT']['DATE']['VALUE'] rescue nil
    @people[k].deathplace = v['DEAT']['PLAC']['VALUE'] rescue nil
    @people[k].famc = v['FAMC']['VALUE'] rescue nil
    @people[k].fams = v['FAMS']['VALUE'] rescue nil
  end

  def ensure_people_families
    @people.each_pair do |id,person|
      if famc = @families[person.famc]
        @people[id].famc = famc
      end
      if fams = @families[person.fams]
        @people[id].fams = fams
      end
    end
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
    recurse_family(people.values.first) do |person, level|
      dot << "#{person.id.inspect} -> #{person.mother.id.inspect} [label=\"mother\"];\n" if person.mother
      dot << "#{person.id.inspect} -> #{person.father.id.inspect} [label=\"father\"];\n" if person.father
    end
    dot << "}\n"
    dot
  end

  def recurse_family(person, level=0, &blk)
    yield person, level
    recurse_family(person.mother, level + 1, &blk) if person.mother
    recurse_family(person.father, level + 1, &blk) if person.father
  end

  private
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

g = Gedcom.new(ARGV[0])

puts g.to_dot

