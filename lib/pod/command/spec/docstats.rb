module Pod
  class Command
    class Spec
      class Docstats < Spec
        self.summary = "Show documentation metrics of Pods."

        self.description = <<-DESC
          Show documentation metrics of Pods.
        DESC

        self.arguments = 'NAME'

        def initialize(argv)
          @name = argv.shift_argument
          @output = './cocoapods-docstats/'
          super
        end

        def validate!
          super
          help! "A Pod name is required." unless @name
        end

        def docstat(docset_path)
          require 'docstat'

          stats  = DocStat.process(docset_path)
          tokens = stats['containers'].map {|c| c['tokens']}.flatten
          ratio  = stats['ratio']
          puts "#{tokens.size} tokens, #{((ratio*1000).to_i/1000.0) * 100}% documented"
        end

        def generate_docset(path, spec)
          headers = headers_for_spec_at_location(path, spec)
          headers.map! { |header| Shellwords.escape header }

          docset_command = [
              "appledoc",
              "--project-name #{spec.name}",                           # name in top left
              "--project-company '#{spec.or_contributors_to_spec}'",   # name in top right
              "--company-id com.cocoadocs.#{spec.name.downcase}",      # the id for the

              "--project-version #{spec.version}",                      # project version
              "--no-install-docset",                                    # don't make a duplicate

              "--keep-intermediate-files",                              # space for now is OK
              "--create-html",                                          # eh, nice to have
              "--publish-docset",                                       # this should create atom

              "--docset-feed-url http://www.cocoadocs.org/docsets/#{spec.name}/xcode-docset.atom",
              "--docset-atom-filename xcode-docset.atom",

              "--docset-package-url http://www.cocoadocs.org/docsets/#{spec.name}/docset.xar",
              "--docset-package-filename docset",

              "--docset-fallback-url http://www.cocoadocs.org/docsets/#{spec.name}",
              "--docset-feed-name #{spec.name}",

              # http://gentlebytes.com/appledoc-docs-examples-advanced/
              "--keep-undocumented-objects",                         # not everyone will be documenting
              "--keep-undocumented-members",                         # so we should at least show something
              "--search-undocumented-doc",                           # uh? ( no idea what this does... )

              "--output #{@output}",                                 # where should we throw stuff
              *headers,
              " >/dev/null"
            ]

            command docset_command.join(' ')
        end

        def headers_for_spec_at_location(path, spec)
          pathlist = Pod::Sandbox::PathList.new( Pathname.new(path) )
          headers = []

          # https://github.com/CocoaPods/cocoadocs.org/issues/35
          [spec, *spec.recursive_subspecs].each do |internal_spec|
            internal_spec.available_platforms.each do |platform|
              consumer = Pod::Specification::Consumer.new(internal_spec, platform)
              accessor = Pod::Sandbox::FileAccessor.new(pathlist, consumer)

              if accessor.public_headers
                headers += accessor.public_headers.map{ |filepath| filepath.to_s }
              else
                puts "Skipping headers for #{internal_spec} on platform #{platform} (no headers found).".blue
              end
            end
          end

          headers.uniq
        end

        def run
          path = get_path_of_spec(@name)
          spec = Specification.from_file(path)

          generate_docset(Dir.pwd, spec)

          docset_path = File.join(@output, "com.cocoadocs.#{spec.name.downcase}." +
              spec.name + '.docset')
          docstat(docset_path)

          FileUtils.rm_rf(@output)
        end
      end
    end
  end
end
