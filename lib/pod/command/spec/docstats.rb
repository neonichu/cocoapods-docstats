module Pod
  class Command
    class Spec
      class Docstats < Spec
        self.summary = "Short description of cocoapods-docstats."

        self.description = <<-DESC
          Longer description of cocoapods-docstats.
        DESC

        self.arguments = 'NAME'

        def initialize(argv)
          @name = argv.shift_argument
          super
        end

        def validate!
          super
          help! "A Pod name is required." unless @name
        end

        def run
          path = get_path_of_spec(@name)
          spec = Specification.from_file(path)
          UI.puts "Hello #{spec.name}"
        end
      end
    end
  end
end
