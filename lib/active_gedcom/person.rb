require 'open-uri'
require 'cgi'
require 'json'

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

    def birthplace_info
      @birthplace_info ||= lookup_location(birthplace)
    end

    def deathplace_latlong
      @deathplace_info ||= lookup_location(deathplace)
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
        dot << "#{person.id.inspect} [label=#{[person.name, person.birthplace, person.birthplace_info['latlong'].to_a.join(', '), "#{[person.birthyear, person.deathyear].compact.join(" - ")}"].join("\n").inspect}];\n"
        if mother = person.mother
          dot << "{ rank = same; #{mother.birthyear}; #{mother.id.inspect} }\n" if mother.birthyear
          dot << "#{mother.id.inspect} -> #{person.id.inspect} [label=\"♀\"];\n"
        end
        if father = person.father
          dot << "{ rank = same; #{father.birthyear}; #{father.id.inspect} }\n" if father.birthyear
          dot << "#{father.id.inspect} -> #{person.id.inspect} [label=\"♂\" color=\"red\"];\n"
        end
      end

      # Year labels
      years = people.map(&:birthyear).uniq.compact.sort
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

    private

    def lookup_location(location)
      begin
        return {} if location.nil?
        return {} if ActiveGedcom::Gedcom.configuration[:mapbox_access_token].nil?

        url = "http://api.tiles.mapbox.com/v4/geocode/mapbox.places-v1/#{CGI.escape location}.json?access_token=#{ActiveGedcom::Gedcom.configuration[:mapbox_access_token]}"

        response = open(url).read
        response = JSON.parse(response)
        response = response['features'][0]  || {} # grab first one?

        # require 'pp'
        # pp response['text']

        {
          "name" => response["place_name"],
          "latlong" => response['center']
        }
      end
    end

  end
end
