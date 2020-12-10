require "lita"

module Lita
  module Handlers
    class Diary < Handler
      REDIS_KEY = "diary"

      config :key_pattern, type: Regexp, default: /[\w\._]+/
      config :key_normalizer do
        validate do |value|
          "must be a callable object" unless value.respond_to?(:call)
        end
      end

      def self.define_routes(pattern)
        route(/^diary\s+new\s+(#{pattern})\s+(.+)/i, :new, command: true, help: {
          "write a new diary" => "saved successfully."
        })

        route(/^diary\s+read\s+(#{pattern})/i, :read, command: true, help: {
          "read diary" => "output one day's diary"
        })

        route(/^diary\s+delete\s+(#{pattern})/i, :delete, command: true, help: {
          "delete diary" => "Delete diary."
        })

        route(/^diary\s+list/i, :list, command: true, help: {
          "list all diary" => "listed"
        })

        route(/^diary\s+modify\s+(#{pattern})\s+(.+)/i, :modify, command: true, help: {
          "diary modify" => "delete and new"
        })
        route(/^show\s+calendar\s+(#{pattern})\s+(.+)/i, :show_calendar, command: true, help: {
          "show calendar" => "saved successfully."
        })

        route(/^show\s+countdown\s+(#{pattern})\s+(.+)/i, :show_birthday, command: true, help: {
          "show birthday" => "saved successfully."
        })

        route(/^show\s+anniversary\s+(#{pattern})\s+(.+)/i, :show_anniversary, command: true, help: {
          "show anniversary" => "saved successfully."
        })

        route( 
          /^double\s+(\d+)$/i,
          :respond_with_double,
          command:true,
          help:{'double N' => 'prints N +N' })
      end

      on :loaded, :define_routes

      def define_routes(payload)
        self.class.define_routes(config.key_pattern.source)
      end

      def new(response)
        key, value = response.matches.first
        key = normalize_key(key)
        redis.hset(REDIS_KEY, key, value)
        response.reply("The diary of #{key} is [#{value}].It has benn saved successfully!")
      end

      def read(response)
        key = normalize_key(response.matches.first.first)
        value = redis.hget(REDIS_KEY, key)

        if value
          response.reply(value)
        else
          response.reply("Maybe you didn't write diary on #{key}.T T")
        end
      end

      def delete(response)
        key = normalize_key(response.matches.first.first)

        if redis.hdel(REDIS_KEY, key) >= 1
          response.reply("Your diary on #{key} was been deleted.")
        else
          response.reply("The diary of #{key} isn't stored.")
        end
      end

      def list(response)
        keys = redis.hkeys(REDIS_KEY)

        if keys.empty?
          response.reply("No diarys are written.")
        else
          response.reply(keys.sort.join(", "))
        end
      end

      def modify(response)
        key, value = response.matches.first
        key = normalize_key(key)
        if redis.hdel(REDIS_KEY, key) >= 1
          redis.hset(REDIS_KEY, key, value)
          response.reply("You have already changed the diary")
        else
          response.reply("You have no diary on #{key}")
        end
      end
   
      def respond_with_double(response)
          n = response.match_data.captures.first
          n = Integer(n)

          response.reply "#{n} + #{n} = #{double_number n}"
      end
      def double_number(n)
          n + n
      end
      #显示日历(年份，月份)
      def show_calendar(response)
        year,month = response.matches.first
        year = year.to_i
        month = month.to_i
        months_run = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        months_ping = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        weeks = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
        line = ""
        weeks.each do |i|
          line = line + ' '
          line = line + i.to_s
        end
        response.reply "#{line}"
        time = Time.gm(*"#{year}-#{month}-1".split("-"))
        current_first_day = time.wday
        number = 0
        if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
          number = months_run[month - 1]
        else
          number = months_ping[month - 1]
        end
        #puts
        #寻找起始位置
        i = current_first_day * 4
        #print((" ") * i)
        top = (" ") * i
        #遍历输出日历
        for i in 1..number
          if i > 9
            top = top+'  '
            #print('  ')
          else
            top = top+'   '
            #print('   ')
          end
          top =top +i.to_s
          current_first_day += 1
          if current_first_day == 7 or i ==number
            current_first_day = 0
            response.reply "#{top}"
            top = ''
          end
        end
      end

      #显示距离生日的天数(年份，月份，天数)
      def show_birthday(response)
        year = response.matches.first[0]
        month,day = response.matches.first[1].split(" ")
        # year = year.to_i
        # month = month.to_i
        # day = day.to_i
        year1 = Time.now().year
        #明年
        year2 = Time.now().year + 1
        #当前时间
        curr = Time.now().strftime("%Y-%m-%d")
        #生日
        da = Time.new(year1, month, day).strftime("%Y-%m-%d")
        if (DateTime.parse(da) - DateTime.parse(curr)).to_i >= 0
          response.reply "That day is #{(DateTime.parse(da) - DateTime.parse(curr)).to_i} days away!"
        else
          response.reply "That day is #{(DateTime.parse(Time.new(year2, month, day).strftime("%Y-%m-%d")) - DateTime.parse(curr)).to_i} days away!"
        end
      end

      #显示距离周年纪念日的天数(年份，月份，天数)
      def show_anniversary(response)
        year = response.matches.first[0]
        month,day = response.matches.first[1].split(" ")
        da = Time.new(year, month, day).strftime("%Y-%m-%d")
        curr = Time.now().strftime("%Y-%m-%d")
        day = DateTime.parse(curr) - DateTime.parse(da)
        if day >= 0
          response.reply "You've been together for #{day.to_i} days！"
        else
          response.reply "You may take off the order ai this time in the future.Be paintent！"
        end
      end
      private

      def config
        Lita.config.handlers.diary
      end

      def normalize_key(key)
        normalizer = config.key_normalizer

        if normalizer
          normalizer.call(key)
        else
          key.to_s.downcase.strip
        end
      end
    end

    Lita.register_handler(Diary)
  end
end
