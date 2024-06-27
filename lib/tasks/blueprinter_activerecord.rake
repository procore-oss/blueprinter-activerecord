namespace :blueprinter do
  namespace :activerecord do
    desc "Prints the preload plan"
    task :preloads, [:blueprint, :view, :model] => :environment do |_, args|
      def pretty(hash, indent = 0)
        s = " " * indent
        buff = "{"
        hash.each { |key, val|
          buff << "\n#{s}  :#{key} => #{pretty val, indent + 2},"
        }
        buff << "\n#{s}" if hash.any?
        buff << "}"
      end

      model = args[:model].constantize
      blueprint = args[:blueprint].constantize
      preloads = BlueprinterActiveRecord::Preloader.preloads(blueprint, args[:view].to_sym, model: model)
      puts pretty preloads
    end
  end
end
