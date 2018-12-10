require 'telegram/bot'

# class WebhooksController < Telegram::Bot::UpdatesController
#   def start!(*)
#     respond_with :message, text: 'Hello!'
#   end
# end

namespace :bot do

  task :run => :environment do

    Telegram::Bot.configure do |config|
      config.ssl_opts = { verify: false }
      config.proxy_opts = {
        uri:  "https://private.kilylabs.com:65506",
        user: 'teleproxy9',
        password: 'teleproxy9',
        socks: true
      }
    end

    TOKEN = '747809885:AAEaA7MNnO2B_VdKqVVsVcuLq67DJESX7Lg'
    BUTTONS = ["Срочная новость", "Комментарий", "Статья", "Посмотреть сообщения"]
    BUTTONS_FROM_HUMAN = {"Срочная новость" => 'hot', "Комментарий" => 'comment', "Статья" => 'article', "Посмотреть сообщения" => 'showall'}
    BUTTONS_TO_HUMAN = {'hot' => "Срочная новость", 'comment' => "Комментарий", 'article' => "Статья", 'showall' => "Посмотреть сообщения"}

    def showall article

    end

    Telegram::Bot::Client.run(TOKEN, logger: Logger.new($stderr)) do |bot|
      bot.logger.info('Bot has been started')
      while true
        bot.listen do |query|
          case query
          when Telegram::Bot::Types::CallbackQuery
            # Here you can handle your callbacks from inline buttons
            message = query.message
            chat_id = message.chat.id
            if %w(hot comment article).include?(query.data)
              article = Article.find_by_message_id(message.reply_to_message.message_id)
              if article
                article.article_type = query.data
                article.save
                bot.api.send_message(chat_id: chat_id, text: "Тип сообщения установлен.")
              else
                bot.api.send_message(chat_id: chat_id, text: "Ошибонька.")
              end
            elsif query.data == 'delete'
              article = Article.find_by_message_id(message.reply_to_message.message_id)
              article.destroy if article
              count = Article.where(chat_id: chat_id).count
              bot.api.send_message(chat_id: chat_id, text: "Удалено. В копилке: #{count}.")
            end
          when Telegram::Bot::Types::Message
            message = query
            chat_id = message.chat.id
            if message.text == '/start'
              question = 'Выберите тип сообщения или отправьте сообщение.'
              answers =
                Telegram::Bot::Types::ReplyKeyboardMarkup
                .new(keyboard: BUTTONS, one_time_keyboard: true, resize_keyboard: true)
              bot.api.send_message(chat_id: chat_id, text: question, reply_markup: answers)
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
                    kb = [
                      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Удалить', callback_data: 'delete', resize_keyboard: true, one_time_keyboard: true)
                    ]
                    markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
                    bot.api.send_message(chat_id: chat_id, text: article.message + "\n\nТип: #{BUTTONS_TO_HUMAN[article.article_type]}", reply_markup: markup, reply_to_message_id: article.message_id) 
                  else
                    kb = [
                      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Срочная новость', callback_data: 'hot', resize_keyboard: true, one_time_keyboard: true),
                      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Комментарий', callback_data: 'comment', resize_keyboard: true, one_time_keyboard: true),
                      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Статья', callback_data: 'article', resize_keyboard: true, one_time_keyboard: true),
                      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Удалить', callback_data: 'delete', resize_keyboard: true, one_time_keyboard: true)
                    ]
                    markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
                    bot.api.send_message(chat_id: chat_id, text: article.message, reply_markup: markup, reply_to_message_id: article.message_id) 
                  end
                end
                bot.api.send_message(chat_id: chat_id, text: "Нет сообщений") if no_articles
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
          break
        end
      end
    end
  end
end