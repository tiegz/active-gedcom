module ActiveGedcom
  class Person
    attr_accessor :id, :name, :sex, :birth, :death, :mother, :father, :famc, :fams, :birthplace, :deathplace
    def initialize(id)
      @id = id
    end
    def mother; famc.wife if famc; end
    def father; famc.husband if famc; end
    def birthyear
      return nil if birth.nil?
      return birth.match(/\d\d\d\d/)[0].to_i
    end
    def deathyear
      return nil if death.nil?
      return death.match(/\d\d\d\d/)[0].to_i
    end

    def to_text
      lines = []
      recurse_family(self) do |person, level|
        lines << "#{'  ' * level}#{person.name}"
      end
      lines.join("\n")
    end


    def to_dot
      dot = "digraph \"gedcom\" {\n"

      years = []

      people = [self]
      recurse_family do |person, level|
        people << person
      end

      dot << "#{id.inspect} [shape=box label=#{birthyear.inspect}]"
      years << birthyear

      dot << "node [shape=box];\n"
      people.each do |person|
        dot << "#{person.id.inspect} [label=#{[person.name, "#{[person.birthyear, person.deathyear].compact.join(" - ")}"].join("\n").inspect}];\n"
        if mother = person.mother
          dot << "{ rank = same; #{mother.birthyear}; #{mother.id.inspect} }\n" if mother.birthyear
          dot << "#{mother.id.inspect} -> #{person.id.inspect} [label=\"♀\"];\n"
          years << mother.birthyear
        end
        if father = person.father
          dot << "{ rank = same; #{father.birthyear}; #{father.id.inspect} }\n" if father.birthyear
          dot << "#{father.id.inspect} -> #{person.id.inspect} [label=\"♂\" color=\"red\"];\n"
          years << father.birthyear
        end
      end

      # Year labels
      years = years.uniq.compact.sort
      dot << "{\n"
      dot << "node [shape=plaintext, fontsize=16];\n"
      dot << "#{years.join(' -> ')};\n" # Timeline
      dot << "#{people.map(&:id).map(&:inspect).join(";")};\n" # Ancestors
      dot << "}\n"

      dot << "}\n"
      dot
    end

    def recurse_family(person=self, level=0, &blk)
      yield person, level
      recurse_family(person.mother, level + 1, &blk) if person.mother
      recurse_family(person.father, level + 1, &blk) if person.father
    end

  end
end
