require "./client"
require "./stanza"
require "./pep"
require "digest/sha1"

module XMPP
  # UserAvatar is a high-level client for XEP-0084 - User Avatar and XEP-0398 -
  # User Avatar to vCard-Based Avatars.
  #
  # Avatars are published to two PEP nodes: a "urn:xmpp:avatar:data" node
  # holding the base64 image bytes and a "urn:xmpp:avatar:metadata" node
  # describing the formats (size, MIME type, and an id hashing the image).
  # Subscribers that receive the metadata fetch the data only if it differs
  # from what they already hold. XEP-0398 bridges this to the legacy
  # vCard-based avatar (XEP-0153) by converting between AvatarData and a vCard
  # PHOTO.
  #
  #   avatar = XMPP::UserAvatar.new(client)
  #   avatar.publish(base64_bytes, "image/png", 2048, width: 64, height: 64)
  #   avatar.subscribe("juliet@capulet.lit")
  #
  #   client.on("message") do |s, p|
  #     if metadata = XMPP::UserAvatar.metadata_from_message(p.as(XMPP::Stanza::Message))
  #       metadata.infos.first.try(&.id)  # fetch the matching data node
  #     end
  #   end
  #
  # See: https://xmpp.org/extensions/xep-0084.html and
  #      https://xmpp.org/extensions/xep-0398.html
  class UserAvatar
    # The PEP node that holds the avatar image bytes.
    NS_DATA = "urn:xmpp:avatar:data"
    # The PEP node that describes the avatar formats.
    NS_METADATA = "urn:xmpp:avatar:metadata"

    def initialize(@client : Client)
    end

    # publish stores an avatar image on the client's data and metadata PEP
    # nodes. data is the base64-encoded image, type its MIME type, and bytes
    # the decoded size in bytes. id hashes the image (defaults to the hex SHA-1
    # of the base64 text).
    def publish(
      data : String,
      type : String,
      bytes : Int32,
      id : String? = nil,
      width : Int32 = 0,
      height : Int32 = 0,
    )
      hash = id || Digest::SHA1.hexdigest(data)
      pep = XMPP::PEP.new(@client)

      data_payload = Stanza::AvatarData.new
      data_payload.data = data
      data_item = Stanza::Item.new
      data_item.id = hash
      data_item.extra = data_payload.to_node
      pep.publish(NS_DATA, data_item)

      metadata = Stanza::AvatarMetadata.new
      info = Stanza::AvatarInfo.new
      info.id = hash
      info.type = type
      info.bytes = bytes
      info.width = width
      info.height = height
      metadata.infos << info
      meta_item = Stanza::Item.new
      meta_item.id = hash
      meta_item.extra = metadata.to_node
      pep.publish(NS_METADATA, meta_item)
    end

    # subscribe subscribes the client to another user's avatar metadata node.
    def subscribe(jid : String)
      XMPP::PEP.new(@client).subscribe(jid, NS_METADATA)
    end

    # unsubscribe removes the client's subscription to a user's avatar
    # metadata node.
    def unsubscribe(jid : String)
      XMPP::PEP.new(@client).unsubscribe(jid, NS_METADATA)
    end

    # metadata_from_message extracts avatar metadata from a PEP notification
    # message, or nil when the message does not carry one.
    def self.metadata_from_message(message : Stanza::Message) : Stanza::AvatarMetadata?
      event = message.get(Stanza::PubSubEvent).as?(Stanza::PubSubEvent)
      return nil unless event
      items = event.items
      return nil unless items && items.node == NS_METADATA
      items.items.each do |item|
        if extra = item.extra
          return Stanza::AvatarMetadata.from_node(extra)
        end
      end
      nil
    end

    # to_vcard_photo builds the vCard PHOTO (XEP-0153) equivalent of an avatar
    # data payload, per XEP-0398 §3.
    def self.to_vcard_photo(data : String, type : String) : Stanza::Photo
      photo = Stanza::Photo.new
      photo.type = type
      photo.binval = data
      photo
    end

    # avatar_from_photo converts a vCard PHOTO into an AvatarData payload, per
    # XEP-0398 §3.
    def self.avatar_from_photo(photo : Stanza::Photo) : Stanza::AvatarData
      data = Stanza::AvatarData.new
      data.data = photo.binval
      data
    end
  end
end
