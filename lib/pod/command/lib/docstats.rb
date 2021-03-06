module Pod
  class Command
    class Lib
      class Docstats < Lib
        self.summary = "Show documentation metrics of Pods."

        self.description = <<-DESC
          Show documentation metrics of Pods.
        DESC

        self.arguments = [CLAide::Argument.new('NAME', true)]

        def self.options
          [
            ['--gutter',     'Generate a gutter.json file.'],
          ]
        end

        def initialize(argv)
          @output = './cocoapods-docstats/'
          @gutter = argv.flag?('gutter')
          super
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

          if headers.count == 0
            raise Informative, "Pod does not expose any public headers."
          end

          docset_command = [
              "appledoc",
              "--logformat xcode",                                     # better log output
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
              " 2>&1 >/dev/null"
            ]

            `#{docset_command.join(' ')}`
        end

        def generate_gutter_json(appledoc_output)
          require 'date'
          require 'json'

          output = { 'meta' => { 'timestamp' => DateTime.now.strftime('%Y-%m-%d %H:%M:%S.%6N') } }
          symbols = {}

          appledoc_output.split("\n").each do |warning|
            s = warning.split(':')
            next unless s.count >= 3
            file = s[0].sub(Dir.pwd + '/', '')

            message = s.slice(2, s.count - 2).join(':')
            message = message.sub(' warning: ', '')

            symbol = { 'line' => s[1], 'short_text' => message }

            if symbols.has_key?(file)
              symbols[file] << symbol
            else
              symbols[file] = [ symbol ]
            end
          end

          output['symbols_by_file'] = symbols
          File.open('.gutter.json', 'w') { |file| file.write(output.to_json) }
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

        def podspecs_to_check
          podspecs = Pathname.glob(Pathname.pwd + '*.podspec{.yaml,}')
          raise Informative, "Unable to find a podspec in the working directory" if podspecs.count.zero?
          podspecs
        end

        def run
          podspecs_to_check.each do |path|
            spec = Specification.from_file(path)

            output = generate_docset(Dir.pwd, spec)
            generate_gutter_json(output) if @gutter

            docset_path = File.join(@output, "com.cocoadocs.#{spec.name.downcase}." +
                spec.name + '.docset')
            docstat(docset_path)

            FileUtils.rm_rf(@output)
          end
        end
      end
    end
  end
end
