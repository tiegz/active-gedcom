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
  end
end
