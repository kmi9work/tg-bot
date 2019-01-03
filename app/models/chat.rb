require 'telegram/bot'

class Chat < ApplicationRecord
  include AASM

  attr_accessor :bot, :query, :message
  
end
