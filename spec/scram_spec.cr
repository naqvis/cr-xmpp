require "./spec_helper"

describe XMPP::SCRAM do
  describe ".parse_server_first" do
    it "strictly validates the SCRAM challenge" do
      nonce = "client-nonce"
      raw = "r=#{nonce}-server,s=QSXCR+Q6sek8bf92,i=4096"
      parsed = XMPP::SCRAM.parse_server_first(Base64.strict_encode(raw), nonce)

      parsed.raw.should eq raw
      parsed.attributes["r"].should eq "#{nonce}-server"
      parsed.attributes["i"].should eq "4096"
    end

    it "rejects weak or excessive iteration counts" do
      nonce = "client-nonce"
      [4095, 1_000_001].each do |iterations|
        raw = "r=#{nonce}-server,s=QSXCR+Q6sek8bf92,i=#{iterations}"
        expect_raises(XMPP::AuthenticationError, /iteration count/) do
          XMPP::SCRAM.parse_server_first(Base64.strict_encode(raw), nonce)
        end
      end
    end

    it "rejects duplicate attributes and a nonce that was not extended" do
      duplicate = "r=client-nonce-server,s=QSXCR+Q6sek8bf92,i=4096,i=4097"
      expect_raises(XMPP::AuthenticationError, /duplicate/) do
        XMPP::SCRAM.parse_server_first(Base64.strict_encode(duplicate), "client-nonce")
      end

      unchanged = "r=client-nonce,s=QSXCR+Q6sek8bf92,i=4096"
      expect_raises(XMPP::AuthenticationError, /did not extend/) do
        XMPP::SCRAM.parse_server_first(Base64.strict_encode(unchanged), "client-nonce")
      end
    end

    it "rejects malformed Base64 and salts" do
      expect_raises(XMPP::AuthenticationError, /invalid Base64/) do
        XMPP::SCRAM.parse_server_first("%%%", "client-nonce")
      end

      malformed_salt = "r=client-nonce-server,s=%%%,i=4096"
      expect_raises(XMPP::AuthenticationError, /invalid Base64/) do
        XMPP::SCRAM.parse_server_first(Base64.strict_encode(malformed_salt), "client-nonce")
      end
    end
  end

  it "matches the RFC 5802 SCRAM-SHA-1 client and server proofs" do
    nonce = "fyko+d2lbbFgONRv9qkxdawL"
    server_nonce = "#{nonce}3rfcNHYJY1ZVvWVs7j"
    initial = "n=user,r=#{nonce}"
    server_first = "r=#{server_nonce},s=QSXCR+Q6sek8bf92,i=4096"
    challenge = {
      "r" => server_nonce,
      "s" => "QSXCR+Q6sek8bf92",
      "i" => "4096",
    }

    response = XMPP::SCRAM.calculate_response(
      "pencil",
      initial,
      server_first,
      challenge,
      OpenSSL::Algorithm::SHA1,
      "n,,",
      nil
    )

    Base64.decode_string(response.encoded).should eq(
      "c=biws,r=#{server_nonce},p=v0X8v3Bz2T0CJGbJQyF0X+HI4Ts="
    )
    response.server_signature.should eq "rmF9pqV8S7suAoZWja4dJRkFsKQ="
  end

  it "verifies the RFC 5802 server-final-message" do
    final = Base64.strict_encode("v=rmF9pqV8S7suAoZWja4dJRkFsKQ=")

    XMPP::SCRAM.verify_server_final!(final, "rmF9pqV8S7suAoZWja4dJRkFsKQ=")
  end

  it "rejects mismatched and malformed server signatures" do
    expect_raises(XMPP::AuthenticationError, /mismatched/) do
      XMPP::SCRAM.verify_server_final!(
        Base64.strict_encode("v=AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
        "rmF9pqV8S7suAoZWja4dJRkFsKQ="
      )
    end

    expect_raises(XMPP::AuthenticationError, /server-final-message/) do
      XMPP::SCRAM.verify_server_final!(Base64.strict_encode("e=invalid-proof"), "AA==")
    end
  end

  it "normalizes SCRAM strings and rejects prohibited characters" do
    XMPP::SCRAM.prepare("\u212B", "password").should eq "\u00C5"

    expect_raises(XMPP::AuthenticationError, /prohibited/) do
      XMPP::SCRAM.prepare("secret\u0000", "password")
    end
  end

  it "uses a constant-time comparison primitive with strict lengths" do
    XMPP::SCRAM.secure_compare(Bytes[1, 2, 3], Bytes[1, 2, 3]).should be_true
    XMPP::SCRAM.secure_compare(Bytes[1, 2, 3], Bytes[1, 2, 4]).should be_false
    XMPP::SCRAM.secure_compare(Bytes[1], Bytes[1, 0]).should be_false
  end
end
