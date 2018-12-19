# frozen_string_literal: true

require "dotenv"
require_relative "helpers"

module Radius
  module Cli
    # CLI command for setting up puma-dev for local HTTPS development
    class PumaDev < Thor::Group
      include Helpers

      DESCRIPTION = "Configure current app for local HTTPS development through puma-dev"

      desc DESCRIPTION

      class_option :cert,
                   type: :boolean,
                   default: false,
                   desc: "Add Puma-dev CA as trusted user cert to login keychain"

      class_option :force,
                   type: :boolean,
                   default: false,
                   desc: "Force overwriting links and ENV settings"

      class_option :setup,
                   type: :boolean,
                   default: false,
                   desc: "Initial puma-dev setup"

      class_option :verbose,
                   type: :boolean,
                   default: false,
                   desc: "Print progress to standard out"

      def toggle_verbosity
        $stdout.reopen(IO::NULL) unless options[:verbose]
      end

      def pow_conflict_check
        return unless system("which pow 1>/dev/null 2>&1")

        abort <<~INFO

          CONFLICT: aborting puma-dev setup because pow is installed
          Please uninstall pow then setup puma-dev.
          See https://github.com/puma/puma-dev
        INFO
      end

      def puma_dev_check
        @cmd = `which puma-dev`.chomp
        abort "Unable to configure puma-dev: not installed" unless $CHILD_STATUS.success?
      end

      def load_env
        Dotenv.load '.env'
      end

      def resetup_check
        @cert = Pathname("~/Library/Application Support/io.puma.dev/cert.pem").expand_path
        return unless options[:setup] && cert.exist?

        puts "puma-dev appears to already be setup."
        printf "Re-install? (y/n) "
        resetup = $stdin.gets(chomp: true).downcase.start_with?("y")
        self.options = options.merge(setup: resetup)
      end

      def puma_dev_setup
        return unless options[:setup]

        puts "Initial puma-dev setup requires sudo access for DNS settings"
        system! "sudo #{cmd} -setup"
        puts "Configuring to run in background..."
        system! "#{cmd} -install"
        options[:cert] = true
        system "#{cmd} -launchd"
        puts <<~MESSAGE

          You'll probably need to reboot before puma-dev runs in the background automatically
        MESSAGE
      end

      def find_keychain
        known_keychains = %w[
          ~/Library/Keychains/login.keychain-db
          ~/Library/Keychains/login.keychain
        ]
        @keychain = known_keychains.map { |chain| Pathname(chain).expand_path }
                                   .find(&:exist?)
      end

      def verify_cert
        return unless options[:cert]

        puts "Verifying Puma-dev CA cert..."
        rewrite = if keychain
                    verify_cmd = %W[security verify-cert -r #{cert} -k #{keychain} -L -p ssl]
                    !system(*verify_cmd)
                  else
                    warn "Unable to locate keychain from list: #{known_keychains}"
                    false
                  end
        self.options = options.merge(cert: rewrite)
      end

      def setup_cert
        return unless options[:cert]

        unless cert.exist?
          abort <<~INFO
            Missing puma-dev cert: #{cert}
            Try setting up puma-dev: #{$PROGRAM_NAME} --setup
          INFO
        end

        puts "Adding trusted Puma-dev CA cert..."
        if keychain
          add_cert_cmd = %W[
            security add-trusted-cert -r trustRoot -p ssl -k #{keychain} #{cert}
          ]
          system!(*add_cert_cmd)
        else
          warn "Unable to locate keychain from list: #{known_keychains}"
        end
      end

      def configure_ssl
        return unless options[:cert]

        puts "\nConfiguring SSL..."
        @combined_cert = Pathname("~/.ssh/pumadev.pem").expand_path
        if combined_cert.exist? && !options[:force]
          puts "Using existing custom CA SSL cert for puma-dev"
          return
        end

        base_cert = Pathname("/usr/local/etc/openssl/cert.pem")
        abort "Missing OS root cert: #{base_cert}" unless base_cert.exist?
        abort "Unable to read root cert: #{base_cert}" unless base_cert.readable?
        abort "Unable to read puma-dev cert: #{cert}" unless cert.readable?
        combined_cert.delete if options[:force] && combined_cert.exist?
        puts "Creating custom CA SSL cert for puma-dev..."
        File.open(combined_cert, "w") do |cert_file|
          cert_file.write base_cert.read
          cert_file.write "\n"
          cert_file.write cert.read
        end
      end

      def configure_app
        puts "\nConfiguring app..."
      end

      def configure_app_ssl
        return unless combined_cert

        cert_env = "SSL_CERT_FILE=\"#{combined_cert.to_path}\""
        env_contents = File.read(env_file)
        env_with_ssl = if env_contents.include?("SSL_CERT_FILE")
                         puts "Updating SSL_CERT_FILE environment variable"
                         env_contents.gsub(/^.*SSL_CERT_FILE.*/, cert_env)
                       else
                         puts "Adding SSL_CERT_FILE environment variable"
                         env_contents + "\n#{cert_env}"
                       end
        File.write env_file, env_with_ssl
      end

      def force_app_ssl
        return unless options[:force]

        puts "Enabling local dev SSL by default..."
        File.write(
          env_file,
          File.read(env_file)
              .gsub(
                %r{http://(?<subdomain>[\w.]+)\.test},
                'https://\k<subdomain>.test',
              )
              .gsub(
                /^.*DISABLE_FORCE_SSL=".*"/,
                'DISABLE_FORCE_SSL="false"',
              ),
        )
      end

      def configure_powrc
        powrc = app_root.join(".powrc")
        chruby_path = Pathname(ENV.fetch("CHRUBY_PATH", "/usr/local/opt/chruby/share/chruby/chruby.sh"))
        if powrc.exist? && !options[:force]
          puts "Using existing .powrc"
          return
        end

        case
        when chruby_path.exist?
          powrc.write <<~EOF
            source /usr/local/opt/chruby/share/chruby/chruby.sh
            chruby $(cat .ruby-version)
          EOF
        when system("which", "rbenv", err: :out, out: IO::NULL) # rubocop:disable Lint/EmptyWhen
          # NOTE: Unclear if `rbenv` systems need a customization / what it should be
        when system("which", "rvm", err: :out, out: IO::NULL)
          powrc.write <<~EOF
            if [ -f "$rvm_path/scripts/rvm" ] && [ -f ".ruby-version" ]; then
              source "$rvm_path/scripts/rvm"
              rvm use `cat .ruby-version`@`cat .ruby-gemset`
            fi
          EOF
        else
          warn "Unknown Ruby version manager. Please install chruby, rbenv, or rvm."
        end
      end

      def link_project
        puts "\nLinking project..."
        link_dir = Pathname("~/.puma-dev").expand_path
        link_path = link_dir.join(app_domain)
        mkdir_p link_dir, verbose: options[:verbose] if options[:force] || !link_dir.exist?
        if options[:force] && (link_path.symlink? || link_path.exist?)
          puts "App link exists. Deleting existing link: #{link_path}"
          link_path.delete
        end
        system! "#{cmd} link -n #{app_domain} #{app_root}" unless link_path.exist?
        puts "Project linked at: #{app_domain}.test"
      end

      def restart_puma_dev
        puts "Restarting puma-dev..."
        system! "#{cmd} -stop"
      end

    private

      attr_reader :cert, :cmd, :combined_cert, :keychain

      def env_file
        app_root.join(".env")
      end
    end
  end
end
