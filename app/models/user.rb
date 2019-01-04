class User < ApplicationRecord
  has_and_belongs_to_many :duties
  serialize :jobs
  has_many :contact_chats
  
  MANY_CELL_CITIES = ['Москва', 'Московская область', 'МО',
                      'Ленинград', 'Санкт-Петербург', 'СПБ', 'Ленинградская область']

  def need_cell?
    MANY_CELL_CITIES.map{|c| c.downcase}.include?(self.city.try(:downcase)) and
      self.cell.blank?
  end
end
