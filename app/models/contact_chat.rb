require 'telegram/bot'

class ContactChat < ApplicationRecord
  include AASM

  TIMEZONES = ["Калининградское время MSK–1 (UTC+2)",
                "Московское время  MSK (UTC+3)",
                "Самарское время MSK+1 (UTC+4)",
                "Екатеринбургское время  MSK+2 (UTC+5)",
                "Омское время  MSK+3 (UTC+6)",
                "Красноярское время  MSK+4 (UTC+7)",
                "Иркутское время MSK+5 (UTC+8)",
                "Якутское время  MSK+6 (UTC+9)",
                "Владивостокское время MSK+7 (UTC+10)",
                "Магаданское время MSK+8 (UTC+11)",
                "Камчатское время  MSK+9 (UTC+12)"]


  attr_accessor :bot, :query, :message

  belongs_to :user

  aasm do
    state :sleeping, initial: true #Не писал ни старт, ничего
    state :starting # Написал start
    event :start do 
      transitions :from => :sleeping, :to => :starting 
    end
    state :signing # Написал /signup - ждет авторизации
    event :sign do 
      transitions :from => :starting, :to => :signing 
    end
    state :authorized # Авторизован
    # event :authorize { transitions :to => :authorized }
    state :waiting_city
    event :wait_city do 
      transitions :to => :waiting_city
    end
    state :waiting_cell
    event :wait_cell do 
      transitions :to => :waiting_cell 
    end
    state :ready
    event :set_ready do 
      transitions :to => :ready 
    end
    state :waiting_team
    event :wait_team do 
      transitions :to => :waiting_team 
    end
    state :waiting_number
    event :wait_number do 
      transitions :to => :waiting_number
    end
    state :waiting_timezone
    event :wait_timezone do 
      transitions :to => :waiting_timezone
    end
  end

  def handle
    if self.user.username == 'mkosten'
      case @query
      when Telegram::Bot::Types::CallbackQuery
        if @query.data.match(/(do_not_)?authorize_(\d+)/)
          user = User.find($2)
          if $1.present?
            user.authorized = false
          else
            user.authorized = true
            ask_city_and_cell user.contact_chats.first.chat_id
          end
          user.save
          return
        end
      end
    end
    case self.aasm.current_state
    when :sleeping
      handle_first
    when :starting
      case @query
      when Telegram::Bot::Types::Message
        if @message.text == '/signup'
          username = @query.from.username.to_s
          self.user = User.find_by_username username
          self.user ||= User.create(username: username)
          if self.user.try(:authorized?)
            ask_city_and_cell
          else
            send_wait
            self.sign && self.save
            call_admin_signup unless self.user.authorized == false
            puts "signing"
          end
        else
          handle_first
        end
      end
    when :signing
      if self.user.try(:authorized?)
        ask_city_and_cell
      else
        send_wait
      end
    when :waiting_city
      case @query
      when Telegram::Bot::Types::Message
        self.user.city = @message.text.strip
        self.user.save
        ask_city_and_cell
      end
    when :waiting_timezone
      case @query
      when Telegram::Bot::Types::Message
        if TIMEZONES.include?(@message.text.strip)
          zone = TIMEZONES.index(@message.text.strip) + 2
          self.user.timezone = zone
          self.user.save
          send_choose_and_ready
        else
          send_ask_timezone
        end
      end
    when :waiting_cell
      case @query
      when Telegram::Bot::Types::Message
        self.user.cell = @message.text.strip
        self.user.save
        send_ask_timezone
      end
    when :waiting_team
      case @query
      when Telegram::Bot::Types::Message
        self.user.team = @message.text.strip
        self.user.save
        send_ask_number
      end
    when :waiting_number
      case @query
      when Telegram::Bot::Types::Message
        unless @message.text.strip == '/no_number'
          self.user.number = @message.text.strip
          self.user.save
        end
        self.set_ready and self.save
        send_choose_and_ready
      end
    when :ready
      case @query
      when Telegram::Bot::Types::Message
        send_choose_and_ready
      when Telegram::Bot::Types::CallbackQuery
        self.user.jobs ||= []
        if @query.data == 'contacts'
          self.user.jobs.push 'contacts' if self.user.try(:authorized?)
          send_choose_and_ready
        elsif @query.data == 'no_contacts'
          self.user.jobs.delete 'contacts'
          send_choose_and_ready
        elsif @query.data == 'notify'
          self.user.jobs.push 'notify' if self.user.try(:authorized?)
          send_ask_team unless self.user.team.present?
        elsif @query.data == 'no_notify'
          self.user.jobs.delete 'notify'
          send_choose_and_ready
        end
        self.user.save
      end
    end
  end

  def handle_first
    username = @query.from.username.to_s
    self.user = User.find_by_username username
    self.save if self.user
    show_first
  end

  private

  def call_admin_signup
    text = "Просит авторизации: #{self.user.username}. Авторизовать?"
    kb = [
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Да', callback_data: "authorize_#{self.user.id}"),
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Нет', callback_data: "do_not_authorize_#{self.user.id}")
    ]
    markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
    user = User.find_by_username 'mkosten'
    bot.api.send_message(chat_id: user.contact_chats.first.chat_id, text: text, reply_markup: markup) 
  end

  def send_ask_timezone
    if self.user.timezone.blank?
      text = "Выберите Вашу временную зону"
      answers =
        Telegram::Bot::Types::ReplyKeyboardMarkup
        .new(keyboard: TIMEZONES, resize_keyboard: true, one_time_keyboard: true)
      bot.api.send_message(chat_id: chat_id, text: text, reply_markup: answers)
      self.wait_timezone and self.save
    else
      send_choose_and_ready
    end
  end

  def send_ask_number
    text = "Введите номер корреспондента для ночных дежурств (если его нет, введите /no_number)"
    res = bot.api.send_message(chat_id: chat_id, text: text)
    self.wait_number and self.save
  end

  def send_ask_team
    text = "Введите номер бригады"
    res = bot.api.send_message(chat_id: chat_id, text: text)
    self.wait_team and self.save
  end

  def send_wait
    text = "Подождите, пока Вас авторизуют. Попробуйте написать боту позднее."
    res = bot.api.send_message(chat_id: chat_id, text: text)
  end

  def ask_city_and_cell id = chat_id
    unless self.user.try(:city)
      text = "Введите город (пока работает только для России. Если нужно зарубежье - пишите @mkosten)."
      res = bot.api.send_message(chat_id: id, text: text)
      self.wait_city && self.save if res['ok']
    else
      if self.user.need_cell?
        ask_cell
      else
        send_ask_timezone
      end
    end
  end

  def ask_cell
    text = "Введите ячейку города #{self.user.try(:city)}."
    res = bot.api.send_message(chat_id: chat_id, text: text)
    self.wait_cell && self.save if res['ok']
  end

  def show_first
    if self.user.try(:authorized?)
      ask_city_and_cell
    else
      text = "Здравствуйте! Запросите доступ командой /signup."
      res = bot.api.send_message(chat_id: chat_id, text: text)
      if res['ok']
        self.start
        self.user ||= User.create(username: @query.from.username.to_s)
        self.save
      end
    end
  end

  def send_choose_and_ready
    text = "#{self.user.try(:username)}, выберите действия."
    kb = []
    if self.user.jobs.present? and self.user.jobs.include? 'contacts'
      kb.push Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Не получать контакты', callback_data: 'no_contacts', resize_keyboard: true, one_time_keyboard: true)
    else
      kb.push Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Получать контакты', callback_data: 'contacts', resize_keyboard: true, one_time_keyboard: true)
    end

    if self.user.jobs.present? and self.user.jobs.include? 'notify'
      kb.push Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Не напоминать о дежурстве', callback_data: 'no_notify', resize_keyboard: true, one_time_keyboard: true)
    else
      kb.push Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Напоминать о дежурстве', callback_data: 'notify', resize_keyboard: true, one_time_keyboard: true)
    end
    markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
    res = bot.api.send_message(chat_id: chat_id, text: text, reply_markup: markup)
    self.set_ready && self.save unless self.aasm.current_state == :ready
  end
end
