require "openssl/pkcs5"
require "openssl/hmac"

module XMPP
  # XEP-0480: SASL Upgrade Tasks
  # Handles SASL mechanism upgrades, particularly SCRAM hash upgrades
  module SASLUpgrade
    # Generate upgrade task name from mechanism
    def self.task_name(mechanism : AuthMechanism) : String
      base = mechanism.base_mechanism
      "UPGR-#{base}"
    end

    # Parse upgrade task name to get mechanism
    def self.parse_task_name(task : String) : String?
      return nil unless task.starts_with?("UPGR-")
      task[5..]
    end

    # Check if a task is a SCRAM upgrade
    def self.scram_upgrade?(task : String) : Bool
      task.starts_with?("UPGR-SCRAM-")
    end

    # Compute SCRAM SaltedPassword for upgrade
    def self.compute_scram_hash(password : String, salt : Bytes, iterations : Int32, algorithm : OpenSSL::Algorithm) : String
      hasher = case algorithm
               when .sha512?
                 OpenSSL::Digest.new("SHA512")
               when .sha256?
                 OpenSSL::Digest.new("SHA256")
               else
                 OpenSSL::Digest.new("SHA1")
               end

      salted_pwd = OpenSSL::PKCS5.pbkdf2_hmac(
        secret: password,
        salt: salt,
        iterations: iterations,
        algorithm: algorithm,
        key_size: hasher.digest_size
      )

      Base64.strict_encode(salted_pwd)
    end

    # Get algorithm from mechanism name
    def self.algorithm_from_mechanism(mechanism : String) : OpenSSL::Algorithm
      case mechanism
      when .includes?("SHA-512")
        OpenSSL::Algorithm::SHA512
      when .includes?("SHA-256")
        OpenSSL::Algorithm::SHA256
      else
        OpenSSL::Algorithm::SHA1
      end
    end

    # Determine which upgrades to request based on available mechanisms and current auth
    def self.select_upgrades(
      current_mechanism : AuthMechanism,
      available_mechanisms : Array(String),
      available_upgrades : Array(String),
    ) : Array(String)
      upgrades = [] of String

      # Only upgrade to stronger SCRAM variants
      current_base = current_mechanism.base_mechanism

      # Priority order for SCRAM upgrades
      upgrade_priority = ["UPGR-SCRAM-SHA-512", "UPGR-SCRAM-SHA-256", "UPGR-SCRAM-SHA-1"]

      upgrade_priority.each do |upgrade_task|
        # Skip if server doesn't support this upgrade
        next unless available_upgrades.includes?(upgrade_task)

        # Extract mechanism name from task
        mechanism = parse_task_name(upgrade_task)
        next unless mechanism

        # Skip if we're already using this mechanism or stronger
        next if current_base == mechanism
        next if current_base == "SCRAM-SHA-512" # Already strongest
        next if current_base == "SCRAM-SHA-256" && mechanism == "SCRAM-SHA-1"

        # Only upgrade to mechanisms the server supports
        if available_mechanisms.includes?(mechanism) || available_mechanisms.includes?("#{mechanism}-PLUS")
          upgrades << upgrade_task
        end
      end

      upgrades
    end
  end

  private class AuthHandler
    # XEP-0480: Perform SCRAM upgrade task
    def perform_scram_upgrade(task : String, algorithm : OpenSSL::Algorithm)
      Logger.info("Performing SASL upgrade: #{task}")

      # Send <next/> to initiate the upgrade task
      send Stanza::SASL2Next.new(task: task)

      # Server sends salt and iteration count
      val = Stanza::Parser.next_packet read_resp
      unless val.is_a?(Stanza::SASL2TaskData)
        raise AuthenticationError.new "Expected task-data for upgrade, got #{val.name}"
      end

      task_data = val.as(Stanza::SASL2TaskData)
      raise AuthenticationError.new "Server sent empty salt" if task_data.salt.blank?
      raise AuthenticationError.new "Server sent invalid iteration count" if task_data.iterations < 4096

      # Decode salt and compute hash
      salt = Base64.decode(task_data.salt)
      hash = SASLUpgrade.compute_scram_hash(@password, salt, task_data.iterations, algorithm)

      # Send computed hash back to server
      response = Stanza::SASL2TaskData.new(hash: hash)
      send response

      Logger.info("SCRAM upgrade #{task} completed")
    end

    # XEP-0480: Handle upgrade tasks after successful authentication
    def handle_upgrade_tasks(upgrades : Array(String))
      return if upgrades.empty?

      Logger.info("Handling #{upgrades.size} upgrade task(s)")

      upgrades.each do |upgrade_task|
        # Read server's continue message
        val = Stanza::Parser.next_packet read_resp
        unless val.is_a?(Stanza::SASL2Continue)
          raise AuthenticationError.new "Expected continue for upgrade, got #{val.name}"
        end

        continue = val.as(Stanza::SASL2Continue)
        raise AuthenticationError.new "Server requested unexpected task" unless continue.tasks.includes?(upgrade_task)

        # Perform the upgrade based on task type
        if SASLUpgrade.scram_upgrade?(upgrade_task)
          mechanism = SASLUpgrade.parse_task_name(upgrade_task)
          raise AuthenticationError.new "Invalid upgrade task name" unless mechanism

          algorithm = SASLUpgrade.algorithm_from_mechanism(mechanism)
          perform_scram_upgrade(upgrade_task, algorithm)
        else
          raise AuthenticationError.new "Unsupported upgrade task: #{upgrade_task}"
        end
      end
    end
  end
end
