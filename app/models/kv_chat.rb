require 'telegram/bot'

class KvChat < Chat

  BUTTONS = [["Срочная новость", "Комментарий", "Статья"], "Посмотреть сообщения", 'Сменить тип использования']
  BUTTONS_FROM_HUMAN = {"Срочная новость" => 'hot', "Комментарий" => 'comment', "Статья" => 'article', "Посмотреть сообщения" => 'showall', 'Сменить тип использования' => 'change_type'}
  BUTTONS_TO_HUMAN = {'hot' => "Срочная новость", 'comment' => "Комментарий", 'article' => "Статья", 'showall' => "Посмотреть сообщения", 'change_type' => 'Сменить тип использования'}

  CHAT_TYPES = ['Отправлять сообщения', 'Получать сообщения']
  CHAT_TYPES_FROM_HUMAN = {'Отправлять сообщения' => 'send', 'Получать сообщения' => 'receive'}

  BUTTONS_RECEIVE = [['Посмотреть все', 'Очистить'], ['Посмотреть статьи', 'Посмотреть комментарии', 'Посмотреть срочные'], 'Сменить тип использования']
  
  kb = [
    Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Удалить', callback_data: 'delete', resize_keyboard: true, one_time_keyboard: true)
  ]
  ONLY_DELETE = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)

  kb = [
    Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Срочная новость', callback_data: 'hot', resize_keyboard: true, one_time_keyboard: true),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Комментарий', callback_data: 'comment', resize_keyboard: true, one_time_keyboard: true),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Статья', callback_data: 'article', resize_keyboard: true, one_time_keyboard: true),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Удалить', callback_data: 'delete', resize_keyboard: true, one_time_keyboard: true)
  ]
  TYPE_AND_DELETE = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)

  def handle
    if chat_type == "send"
      send_handler
    elsif chat_type == "receive"
      receive_handler
    end
  end

  def handle_first
    if chat_type == 'receive'
      show_receiver_all
    elsif chat_type == 'send'
      show_sender_all
    end
  end

  private

  def show_sender_all
    question = 'Выберите тип сообщения или отправьте сообщение.'
    answers =
      Telegram::Bot::Types::ReplyKeyboardMarkup
      .new(keyboard: BUTTONS, resize_keyboard: true)
    @bot.api.send_message(chat_id: chat_id, text: question, reply_markup: answers)
  end

  def send_buttons_pressed
    if BUTTONS.flatten[0..2].include?(@message.text)
      article = Article.where(chat_id: chat_id).where('message is null').first
      if article.present?
        article.article_type = BUTTONS_FROM_HUMAN[@message.text]
        article.save
      else
        Article.create(chat_id: chat_id, article_type: BUTTONS_FROM_HUMAN[@message.text])
      end
      @bot.api.send_message(chat_id: chat_id, text: "Тип сообщения установлен.")
    elsif @message.text == 'Посмотреть сообщения'
      no_articles = true
      Article.where(chat_id: chat_id).each do |article|
        no_articles = false
        if article.article_type.present?
          res = @bot.api.send_message(chat_id: chat_id, text: "#{article.message}\n\nТип: #{BUTTONS_TO_HUMAN[article.article_type]}", reply_markup: ONLY_DELETE)
        else
          res = @bot.api.send_message(chat_id: chat_id, text: article.message, reply_markup: TYPE_AND_DELETE) 
        end
        article.message_id = res['result']['message_id'].to_i
        article.save
      end
      @bot.api.send_message(chat_id: chat_id, text: "Нет сообщений") if no_articles
    elsif @message.text == 'Сменить тип использования'
      self.chat_type = 'receive'
      self.save
      show_receiver_all
    end
  end

  def message_received
    article = Article.where(chat_id: chat_id).where('message is null').first
    if article.present?
      article.update(message: @message, message_id: @message.message_id)
      article.save
    else
      Article.create(chat_id: chat_id, message: @message, message_id: @message.message_id)
    end
    @bot.api.send_message(chat_id: chat_id, text: "Сообщение сохранено") 
  end

  def send_handler
    case @query
    when Telegram::Bot::Types::Message
      if @message.text == '/start'
        show_sender_all
      elsif @message.text == '/help'
        @bot.api.send_message(chat_id: chat_id, text: "Выберите тип сообщения или отправьте сообщение.")
      elsif BUTTONS.flatten.include?(@message.text)
        send_buttons_pressed
      else
        message_received
      end
    when Telegram::Bot::Types::CallbackQuery
      if %w(hot comment article).include?(@query.data)
        article = Article.find_by_message_id(@message.message_id)
        if article
          article.article_type = @query.data
          article.save
          @bot.api.send_message(chat_id: chat_id, text: "Тип сообщения установлен.")
        else
          @bot.api.send_message(chat_id: chat_id, text: "Ошибонька.")
        end
      elsif @query.data == 'delete'
        article = Article.find_by_message_id(@message.message_id)
        article.destroy if article
        count = Article.where(chat_id: chat_id).count
        @bot.api.delete_message(chat_id: chat_id, message_id: @message.message_id)
        @bot.api.send_message(chat_id: chat_id, text: "Удалено. В копилке: #{count}.")
      end
    end
  end

  def look_button_clicked
    if @message.text == 'Посмотреть все'
      return_messages = Article.all
    elsif @message.text == 'Посмотреть статьи' 
      return_messages = Article.where(article_type: 'article')
    elsif @message.text == 'Посмотреть комментарии'
      return_messages = Article.where(article_type: 'comment')
    elsif @message.text == 'Посмотреть срочные'
      return_messages = Article.where(article_type: 'hot')
    end
    no_articles = true
    return_messages.each do |article|
      no_articles = false
      res = @bot.api.send_message(
        chat_id: chat_id, 
        text: "#{article.message}\n\nТип: #{BUTTONS_TO_HUMAN[article.article_type] || 'Неизвестно'}", 
        reply_markup: ONLY_DELETE)

      article.message_id = res['result']['message_id'].to_i
      article.save
    end
    @bot.api.send_message(chat_id: chat_id, text: "Нет сообщений") if no_articles
  end

  def receive_handler
    case @query
    when Telegram::Bot::Types::Message
      if @message.text == '/start'
        show_receiver_all
      elsif ['Посмотреть все', 'Посмотреть статьи', 'Посмотреть комментарии', 'Посмотреть срочные'].include? @message.text
        look_button_clicked
      elsif @message.text == 'Очистить'
        question = "Удалить все сообщения?"
        kb = [
          Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Удалить', callback_data: 'delete_all', resize_keyboard: true, one_time_keyboard: true),
          Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Отмена', callback_data: 'cancel_delete', resize_keyboard: true, one_time_keyboard: true)
        ]
        markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
        @bot.api.send_message(chat_id: chat_id, text: question, reply_markup: markup) 
      elsif @message.text == 'Сменить тип использования'
        self.chat_type = 'send'
        self.save
        show_sender_all
      end
    when Telegram::Bot::Types::CallbackQuery
      if @query.data == 'delete_all'
        Article.all.delete_all
        show_receiver_all
      elsif @query.data == 'cancel_delete'
        show_receiver_all
      end
    end
  end

  def show_receiver_all
    count = Article.count
    count_articles = Article.where(article_type: 'article').count
    count_hot = Article.where(article_type: 'hot').count
    count_comment = Article.where(article_type: 'comment').count
    question = "В базе #{count} сообщений.\nСтатей: #{count_articles}\nСрочных: #{count_hot}\nС комментариями: #{count_comment}\nПосмотреть?"
    answers =
      Telegram::Bot::Types::ReplyKeyboardMarkup
      .new(keyboard: BUTTONS_RECEIVE, resize_keyboard: true)
    @bot.api.send_message(chat_id: chat_id, text: question, reply_markup: answers)
  end
end
