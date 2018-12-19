require 'telegram/bot'

# class WebhooksController < Telegram::Bot::UpdatesController
#   def start!(*)
#     respond_with :message, text: 'Hello!'
#   end
# end

namespace :bot do

  task :run => :environment do

    # Telegram::Bot.configure do |config|
    #   config.ssl_opts = { verify: false }
    #   config.proxy_opts = {
    #     uri:  "https://private.kilylabs.com:65506",
    #     user: 'teleproxy9',
    #     password: 'teleproxy9',
    #     socks: true
    #   }
    # end

    TOKEN = '747809885:AAEaA7MNnO2B_VdKqVVsVcuLq67DJESX7Lg'
    BUTTONS = ["Срочная новость", "Комментарий", "Статья", "Посмотреть сообщения"]
    BUTTONS_FROM_HUMAN = {"Срочная новость" => 'hot', "Комментарий" => 'comment', "Статья" => 'article', "Посмотреть сообщения" => 'showall'}
    BUTTONS_TO_HUMAN = {'hot' => "Срочная новость", 'comment' => "Комментарий", 'article' => "Статья", 'showall' => "Посмотреть сообщения"}

    CHAT_TYPES = ['Отправлять сообщения', 'Получать сообщения']
    CHAT_TYPES_FROM_HUMAN = {'Отправлять сообщения' => 'send', 'Получать сообщения' => 'receive'}

    BUTTONS_RECEIVE = ['Посмотреть', 'Очистить']
    
    kb = [
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Удалить', callback_data: 'delete', resize_keyboard: true, one_time_keyboard: true)
    ]
    only_delete = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)

    kb = [
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Срочная новость', callback_data: 'hot', resize_keyboard: true, one_time_keyboard: true),
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Комментарий', callback_data: 'comment', resize_keyboard: true, one_time_keyboard: true),
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Статья', callback_data: 'article', resize_keyboard: true, one_time_keyboard: true),
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Удалить', callback_data: 'delete', resize_keyboard: true, one_time_keyboard: true)
    ]
    type_and_delete = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)

    def show_sender_all bot, query, message, chat_id
      question = 'Выберите тип сообщения или отправьте сообщение.'
      answers =
        Telegram::Bot::Types::ReplyKeyboardMarkup
        .new(keyboard: BUTTONS, resize_keyboard: true)
      bot.api.send_message(chat_id: chat_id, text: question, reply_markup: answers)
    end

    def send_worker bot, query, message, chat_id
      case query
      when Telegram::Bot::Types::Message
        if message.text == '/start'
          show_sender_all bot, query, message, chat_id
        elsif message.text == '/help'
          bot.api.send_message(chat_id: chat_id, text: "Выберите тип сообщения или отправьте сообщение.")
        elsif BUTTONS.include?(message.text)
          if BUTTONS[0..2].include?(message.text)
            article = Article.where(chat_id: chat_id).where('message is null').first
            if article.present?
              article.article_type = BUTTONS_FROM_HUMAN[message.text]
              article.save
            else
              Article.create(chat_id: chat_id, article_type: BUTTONS_FROM_HUMAN[message.text])
            end
            bot.api.send_message(chat_id: chat_id, text: "Тип сообщения установлен.")
          else #showall
            no_articles = true
            Article.where(chat_id: chat_id).each do |article|
              no_articles = false
              if article.article_type.present?
                
                res = bot.api.send_message(chat_id: chat_id, text: article.message + "\n\nТип: #{BUTTONS_TO_HUMAN[article.article_type]}", reply_markup: only_delete)
              else
                res = bot.api.send_message(chat_id: chat_id, text: article.message, reply_markup: type_and_delete) 
              end
              article.message_id = res['result']['message_id'].to_i
              article.save
            end
            bot.api.send_message(chat_id: chat_id, text: "Нет сообщений") if no_articles
          end
        end
      when Telegram::Bot::Types::CallbackQuery
        if %w(hot comment article).include?(query.data)
          article = Article.find_by_message_id(message.message_id)
          if article
            article.article_type = query.data
            article.save
            bot.api.send_message(chat_id: chat_id, text: "Тип сообщения установлен.")
          else
            bot.api.send_message(chat_id: chat_id, text: "Ошибонька.")
          end
        elsif query.data == 'delete'
          article = Article.find_by_message_id(message.message_id)
          article.destroy if article
          count = Article.where(chat_id: chat_id).count
          bot.api.delete_message(chat_id: chat_id, message_id: message.message_id)
          bot.api.send_message(chat_id: chat_id, text: "Удалено. В копилке: #{count}.")
        end
      else
        article = Article.where(chat_id: chat_id).where('message is null').first
        if article.present?
          article.update(message: message, message_id: message.message_id)
          article.save
        else
          Article.create(chat_id: chat_id, message: message, message_id: message.message_id)
        end
        bot.api.send_message(chat_id: chat_id, text: "Сообщение сохранено") 
      end
    end

    def show_receiver_all bot, query, message, chat_id
      count = Article.count
      count_articles = Article.where(article_type: 'article').count
      count_hot = Article.where(article_type: 'hot').count
      count_comment = Article.where(article_type: 'comment').count
      question = "В базе #{count} сообщений.\nСтатей: #{count_articles}\nСрочных: #{count_hot}\nС комментариями: #{count_comment}\nПосмотреть?"
      answers =
        Telegram::Bot::Types::ReplyKeyboardMarkup
        .new(keyboard: BUTTONS_RECEIVE, resize_keyboard: true)
      bot.api.send_message(chat_id: chat_id, text: question, reply_markup: answers)
    end

    def receive_worker bot, query, message, chat_id
      case query
      when Telegram::Bot::Types::Message
        if message.text == '/start'
          show_receiver_all bot, query, message, chat_id
        end
      end
    end

    Telegram::Bot::Client.run(TOKEN, logger: Logger.new($stderr)) do |bot|
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
        chat = Chat.find_by_chat_id chat_id
        if chat.present? and chat.chat_type.present?
          if chat.chat_type == "send"
            send_worker bot, query, message, chat_id
          elsif chat.chat_type == "receive"
            receive_worker bot, query, message, chat_id
          else
          end
        else
          # Новый пользователь
          case query
          when Telegram::Bot::Types::Message
            if CHAT_TYPES.include? message.text
              chat ||= Chat.new(chat_id: chat_id)
              chat.chat_type = CHAT_TYPES_FROM_HUMAN[message.text]
              chat.save
              if chat.chat_type == 'reveive'
                show_receiver_all bot, query, message, chat_id
              else

              end
            else
              question = "Отправлять или получать сообщения?"
              answers =
                Telegram::Bot::Types::ReplyKeyboardMarkup
                .new(keyboard: ['Отправлять сообщения', 'Получать сообщения'], one_time_keyboard: true, resize_keyboard: true)
              bot.api.send_message(chat_id: chat_id, text: question, reply_markup: answers)
            end
          end
        end
      end
    end
  end
end