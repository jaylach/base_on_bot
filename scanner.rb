module BaseOnBot
  class Scanner
    # -----
    #   Constructor
    # -----

    # initialize()
    def initialize(reddit, config)
      @reddit = reddit
      @config = config

      # Build our regex
      abbrvs = @config['sources'].map do |item|
        item['abbrv'].downcase
      end

      @comment_regex = /[_*]([^_*]+?)\s+\((#{abbrvs.join('|')})\)[_*]/i
    end #- initialize()

    # -----
    #   Public
    # -----

    def get_replies()
      get_all_comments()
    end

    # -----
    #   Private
    # -----
    private

    #####
    # THIS IS A TERRIBLE HACK!!!!
    # There I said it. I need a much better way of tracking which comments I've already replied to.
    # Problem is, snoo does not tell me if the post failed due to throttling, so I can't just track
    # everything I think I replied to. 
    #
    # It's just terrible to making all these extra requests. I hate it and I hate myself for hacking
    # this together.. but it's working for now.
    #
    # BEGIN HACKS
    #####

    # already_replied?()
    def already_replied(link_id, comment_id)
      posted = false

      begin
        listing = @reddit.get_comments(link_id: link_id, comment_id: comment_id, limit: 100)
        listing.each do |item|
          children = item['data']['children'].select { |i| i['kind'] == 't1' }
          children.each do |c|
            replies = c['data']['replies']
            if replies.is_a?(Hash)
              arr = replies['data']['children']
              posted = arr.any? do |a|
                a['data']['author'].downcase() == 'baseonbot'
              end

              break if posted == true
            end
          end

          break if posted == true
        end
      rescue Exception => e
        posted = false
      end

      posted
    end #- already_replied()

    #####
    # END HACKS
    #####

    # get_all_comments()
    def get_all_comments()
      listing = @reddit.get_comments(subreddit: 'baseball', limit: 100, depth: 1000, sort: 'new')
      comments = Array.new()

      temp = listing['data']['children']
      traverse_comments temp, comments

      comments
    end #- get_all_comments()

    # traverse_comments()
    def traverse_comments(listing, all_comments)
      listing.each do |item|
        data = item['data']
        id = "#{item['kind']}_#{data['id']}"
        body = data['body']
        matches = body.scan(@comment_regex)
        
        if matches.length > 0
          sleep 2
          link_id = data['link_id'].slice(3, data['link_id'].length)
          posted = already_replied(link_id, data['id'])

          if !posted
            all_comments.push({
              :id => id, 
              :reply => build_reply(matches)
            })
          end
        end
      end
    end #- traverse_comments()

    # build_reply()
    def build_reply(matches)
      replies = Array.new()

      matches.each do |match|
        term = match[0]
        source = match[1].downcase

        raw_source = @config['sources'].find do |s|
          s['abbrv'].downcase == source
        end

        if raw_source != nil
          link = raw_source['player_link']

          if term_is_team(term)
            link = raw_source['mlb_team_link']
          end

          if link != nil 
            link = link + term.gsub(' ', '+')

            reply = "> [#{term} @ #{raw_source['name']}](#{link})  "
            replies.push reply
          end
        end
      end

      # Build our reply
      joined = replies.uniq.join("\n\n")
      "Here's some clicky goodness for you:\n\n#{joined}"
    end #- build_reply()

    # term_is_team()
    def term_is_team(term)
      teams = @config['teams']['mlb']
      teams.include?(term.downcase)
    end #- term_is_team()
  end
end