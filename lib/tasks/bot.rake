require 'telegram/bot'

# class WebhooksController < Telegram::Bot::UpdatesController
#   def start!(*)
#     respond_with :message, text: 'Hello!'
#   end
# end

namespace :bot do

  desc "kv"
  task :kv => :environment do
    client = Telegram::Bot::Client.new(TOKEN, logger: Logger.new($stderr))
    BOTNAME = 'RPMainBot'
    TOKEN = '747809885:AAEaA7MNnO2B_VdKqVVsVcuLq67DJESX7Lg'
    client.run do |bot|
      bot.logger.info('Bot has been started')
      bot.listen do |query|
        case query
        when Telegram::Bot::Types::Message
          message = query
          chat_id = message.chat.id
        when Telegram::Bot::Types::CallbackQuery
          message = query.message
          chat_id = message.chat.id
        end
        chat = KvChat.find_by_chat_id chat_id
        if chat.present? and chat.chat_type.present?
          chat.bot = bot
          chat.query = query
          chat.message = message
          if ["send", "receive"].include? chat.chat_type
            chat.handle
          end
        else
          # Новый пользователь
          case query
          when Telegram::Bot::Types::Message
            if KvChat::CHAT_TYPES.include? message.text
              chat ||= KvChat.new(chat_id: chat_id)
              chat.chat_type = KvChat::CHAT_TYPES_FROM_HUMAN[message.text]
              chat.save
              chat.bot = bot
              chat.query = query
              chat.message = message
              chat.handle_first
            else
              question = "Отправлять или получать сообщения?"
              answers =
                Telegram::Bot::Types::ReplyKeyboardMarkup
                .new(keyboard: KvChat::CHAT_TYPES, one_time_keyboard: true, resize_keyboard: true)
              bot.api.send_message(chat_id: chat_id, text: question, reply_markup: answers)
            end
          end
        end
      end
    end
  end

  def send_contacts api
    Contact.where(state: 'new').each do |contact|
      chat = ContactChat.where(chat_type: 'contacts', state: 'authorized')
      if chat.present?
        res = api.send_message(chat_id: chat.chat_id, 
          text: "Новый контакт #в_ячейку:\n#{contact.sku}: #{contact.name}, #{contact.phone.sub(/^8/,'+7')} - #{contact.city}, #{contact.region}\n#{contact.own_comment}")
        if res['ok']
          contact.state = "sent"
          contact.save
        end
      else
        break
      end
    end
  end

  def send_notify api
    ContactChat.joins(:user).where(chat_type: 'contacts').where("users.jobs like '%notify%'").each do |chat|
      userhour = (Time.now.utc + chat.user.timezone.hours).hour
      if userhour > 10 and userhour < 22
        Duty.where(team: chat.user.try(:team)).where("date(day) = date('now', '+1 day')").each do |duty|
          if duty.present? and !duty.users.include?(chat.user)
            if !duty.number.present? or chat.user.number == duty.number
              if duty.start_hour < 8
                text = "У вас ночью дежурство. С #{duty.start_hour}:00 до #{duty.start_hour+4}:00. Бригадир #{duty.leader}."
              else
                text = "У вас завтра дежурство. С #{duty.start_hour}:00 до #{duty.start_hour+4}:00. Бригадир #{duty.leader}."
              end
              res = api.send_message(chat_id: chat.chat_id, text: text)
              duty.users << chat.user if res['ok']
            end
          end
        end
      end
    end
  end

  task :contacts => :environment do

    Telegram::Bot.configure do |config|
      config.ssl_opts = { verify: false }
      config.proxy_opts = {
        uri:  "https://private.kilylabs.com:65506",
        user: 'teleproxy9',
        password: 'teleproxy9',
        socks: true
      }
    end

    BOTNAME = 'kv_contacts_bot'
    TOKEN = '762400042:AAE9RGE7A9Pyi-NTWY6eYij7-t0r0f0qN4E'

    client = Telegram::Bot::Client.new(TOKEN, logger: Logger.new($stderr))
    client.task = lambda do |api|
      send_contacts(api)
      send_notify(api)
    end

    client.run do |bot|
      bot.logger.info('Bot has been started')
      bot.listen do |query|
        case query
        when Telegram::Bot::Types::Message
          message = query
          chat_id = message.chat.id
        when Telegram::Bot::Types::CallbackQuery
          message = query.message
          chat_id = message.chat.id
        end
        chat = ContactChat.find_by_chat_id chat_id
        if chat.present?
          chat.bot = bot
          chat.query = query
          chat.message = message
          chat.handle
        else
          # Новый пользователь
          case query
          when Telegram::Bot::Types::Message
            if message.text == '/start'
              chat ||= ContactChat.new(chat_id: chat_id)
              chat.chat_type = 'contacts'
              chat.save
              chat.bot = bot
              chat.query = query
              chat.message = message
              chat.handle
            elsif message.text == '/help'
              text = 'Для начала работы введите /start'
              bot.api.send_message(chat_id: chat_id, text: text)
            else
              chat ||= ContactChat.new(chat_id: chat_id)
              chat.chat_type = 'contacts'
              chat.save
              chat.bot = bot
              chat.query = query
              chat.message = message
              chat.handle_first
            end
          end
        end
      end
    end
  end
end