#!/usr/bin/env ruby

require 'rexml/document'
require 'cgi'
require 'uri'
require 'net/http'

APIKEY = "88ba38d6538a59e371fbafa3339773ab"
APIURL = "http://ws.audioscrobbler.com/2.0/?api_key=#{APIKEY}&"

module ::Spotify
  class SpotifyObject
    attr_reader :spotify_id

    def initialize(xml)
      @spotify_id = xml.attributes["href"]
    end

    def url
      id = @spotify_id[@spotify_id.rindex(':')+1..-1]
      method = self.class.to_s.split('::').last.downcase
      return "http://open.spotify.com/#{method}/#{id}"
    end
  end

  class Album < SpotifyObject
    attr_reader :name, :released, :artist

    def initialize(xml)
      super
      @name = xml.elements["name"].text
      if e = xml.elements["artist"]
        @artist = Artist.new(xml.elements["artist"])
      end
      if e = xml.elements["released"]
        @released = e.text.to_i
      end
    end
  end

  class Artist < SpotifyObject
    attr_reader :name

    def initialize(xml)
      super
      @name = xml.elements["name"].text
    end
  end

  class Track < SpotifyObject
    attr_reader :name, :artist, :album, :track_number

    def initialize(xml)
      super
      @name = xml.elements["name"].text
      @artist = Artist.new(xml.elements["artist"])
      @album = Album.new(xml.elements["album"])
      @track_number = xml.elements["track-number"].text.to_i
      @length = xml.elements["length"].text.to_f
    end

    def to_s
      str = "#{artist.name} – #{name} [#{album.name}"
      str << ", #{album.released}" if album.released
      str << "]"
    end
  end

  def self.get(service, method, query, page=1)
    query.tr!('-','')
    url = "http://ws.spotify.com/#{service}/1/#{method}?q=#{CGI.escape(query)}&page=#{page}"
    xml = Net::HTTP.get(URI.parse(url))
    raise unless xml
    return REXML::Document.new(xml).root
  end

  def self.search(method, query, page=1)
    doc = get(:search, method, query, page)
    return nil if doc.elements["opensearch:totalResults"].text.to_i.zero?
    return Spotify.const_get(method.to_s.capitalize).new(doc.elements[method.to_s])
  end
end

user = ARGV[0] || (puts "usage: lastfm2spotify [username]"; exit)

spotify_ids = []
xml = Net::HTTP.get(URI.parse("#{APIURL}method=user.getlovedtracks&user=#{user}&limit=0"))
doc = REXML::Document.new(xml)
tracks = doc.root.elements["lovedtracks"].elements.to_a
tracks.each_with_index do |t,i|
  print "\rFetching tracks... [#{i+1}/#{tracks.size}]"
  STDOUT.flush

  track_name = t.elements["name"].text
  artist = t.elements["artist/name"].text

  track = Spotify.search(:track, "artist:'#{artist}' track:'#{track_name}'")
  spotify_ids << track.spotify_id if track
end

IO.popen('pbcopy', 'r+') do |clipboard|
  clipboard.puts spotify_ids.join(" ")
end

puts
puts "Done! Now create a new playlist or open an existing one in Spotify and paste (Command-V)"