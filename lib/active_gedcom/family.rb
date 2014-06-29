module ActiveGedcom
  class Family
    attr_accessor :children, :wife, :husband
    def initialize(id)
      @id = id
      @children = []
    end
  end
end