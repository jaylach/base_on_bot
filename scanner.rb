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

      @comment_regex = /_([^_]+?)\s+\((#{abbrvs.join('|')})\)_/i
    end #- initialize()

    # -----
    #   Public
    # -----

    def get_replies()
      get_replies_needed()
    end

    # -----
    #   Private
    # -----
    private

    # get_replies_needed()
    def get_replies_needed()
      # get_post_comments '1pnk9y'
      get_all_comments()
    end #- get_replies_needed()

    # get_new_posts()
    def get_new_posts()
      listing = @reddit.get_listing(subreddit: 'baseball', page: 'new', limit: 100)['data']['children']
      posts = Array.new()

      listing.each do |item|
        if item['data']['num_comments'] > 0
          post_id = item['data']['id']
          posts.push post_id
        end
      end

      posts
    end #- get_new_posts()

    # get_post_comments()
    def get_post_comments(post_id)
      listing = @reddit.get_comments(link_id: post_id)
      comments = Array.new()

      listing.each do |item|
        traverse_comments item, comments
      end

      comments
    end #- get_post_comments()

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
          all_comments.push({
            :id => id, 
            :reply => build_reply(matches)
          })
        end

        replies = data['replies']
        if replies.is_a?(Hash)
          traverse_comments replies, all_comments
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

            reply = "[#{term} @ #{raw_source['name']}](#{link})"
            replies.push reply
          end
        end
      end

      # Build our reply
      joined = replies.join(", ")
      "Here's some clicky goodness for you:\n\n#{joined}"
    end #- build_reply()

    # term_is_team()
    def term_is_team(term)
      teams = @config['teams']['mlb']
      teams.include?(term.downcase)
    end #- term_is_team()
  end
end