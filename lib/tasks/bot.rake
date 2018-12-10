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

    def showall article

    end

    Telegram::Bot::Client.run(TOKEN, logger: Logger.new($stderr)) do |bot|
      bot.logger.info('Bot has been started')
      articles = {} ##
      bot.listen do |query|
        case query
        when Telegram::Bot::Types::CallbackQuery
          # Here you can handle your callbacks from inline buttons
          message = query.message
          chat_id = message.chat.id
          if %w(hot comment article).include?(query.data)
            articles[chat_id] = query.data
            bot.api.send_message(chat_id: chat_id, text: "Тип сообщения установлен.")
          elsif query.data == 'showall'
            Article.where(chat_id: chat_id).each do |article|
              bot.api.send_message(chat_id: chat_id, text: article.text) 
            end
          end
        when Telegram::Bot::Types::Message
          message = query
          chat_id = message.chat.id
          if message.text == '/start'
            question = 'Выберите тип сообщения или отправьте сообщение.'
            kb = [
              Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Срочная новость', callback_data: 'hot', resize_keyboard: true, one_time_keyboard: true),
              Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Комментарий', callback_data: 'comment', resize_keyboard: true, one_time_keyboard: true),
              Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Статья', callback_data: 'article', resize_keyboard: true, one_time_keyboard: true),
              Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Посмотреть сообщения', callback_data: 'showall', resize_keyboard: true, one_time_keyboard: true)
            ]
            markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
            bot.api.send_message(chat_id: chat_id, text: question, reply_markup: markup)
            # See more: https://core.telegram.org/bots/api#replykeyboardmarkup
            answers =
              Telegram::Bot::Types::ReplyKeyboardMarkup
              .new(keyboard: BUTTONS, one_time_keyboard: true, resize_keyboard: true)
            bot.api.send_message(chat_id: chat_id, text: question, reply_markup: answers)
          elsif message.text == '/help'
            bot.api.send_message(chat_id: chat_id, text: "Выберите тип сообщения или отправьте сообщение.")
          elsif BUTTONS.include?(message.text)
            if BUTTONS[0..2].include?(message.text)
              articles[chat_id] = BUTTONS_FROM_HUMAN[message.text]
              bot.api.send_message(chat_id: chat_id, text: "Тип сообщения установлен.")
            else #showall
              Article.where(chat_id: chat_id).each do |article|
                bot.api.send_message(chat_id: chat_id, text: article.text) 
              end
            end
          else
            Article.create(type: articles[chat_id], chat_id: chat_id, message: message)
            bot.api.send_message(chat_id: chat_id, text: "Сообщение сохранено") 
          end
        # when Telegram::Bot::Types::InlineQuery
        #   results = [
        #     [1, 'First article', 'Very interesting text goes here.'],
        #     [2, 'Second article', 'Another interesting text here.']
        #   ].map do |arr|
        #     Telegram::Bot::Types::InlineQueryResultArticle.new(
        #       id: arr[0],
        #       title: arr[1],
        #       input_message_content: Telegram::Bot::Types::InputTextMessageContent.new(message_text: arr[2])
        #     )
        #   end

        #   bot.api.answer_inline_query(inline_query_id: message.id, results: results)
        end
        
      end
    end
  end
end