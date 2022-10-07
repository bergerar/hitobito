# frozen_string_literal: true

#  Copyright (c) 2012-2017, Jungwacht Blauring Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.
# == Schema Information
#
# Table name: invoice_items
#
#  id          :integer          not null, primary key
#  account     :string(255)
#  cost_center :string(255)
#  count       :integer          default(1), not null
#  description :text(16777215)
#  name        :string(255)      not null
#  unit_cost   :decimal(12, 2)   not null
#  vat_rate    :decimal(5, 2)
#  invoice_id  :integer          not null
#
# Indexes
#
#  index_invoice_items_on_invoice_id  (invoice_id)
#

class InvoiceItem < ActiveRecord::Base
  class_attribute :dynamic
  class_attribute :dynamic_cost_parameter_keys

  self.dynamic = false
  self.dynamic_cost_parameter_keys = []

  after_destroy :recalculate_invoice!

  belongs_to :invoice

  scope :list, -> { order(:name) }

  validates :unit_cost, money: true, allow_nil: true
  validates :unit_cost, presence: true, unless: :dynamic
  validates :count, presence: true, unless: :dynamic

  serialize :dynamic_cost_parameters, Hash

  class << self
    def all_types
      [InvoiceItem] + InvoiceItem.subclasses
    end

    def find_invoice_item_type!(sti_name)
      type = all_types.detect { |t| t.sti_name == sti_name }
      raise ActiveRecord::RecordNotFound, "No invoice_item type '#{sti_name}' found" if type.nil?

      type
    end
  end

  def to_s
    "#{name}: #{total} (#{amount} / #{vat})"
  end

  def total
    recalculate unless cost

    cost&.+ vat
  end

  def recalculate!
    recalculate

    save!

    invoice.recalculate!
  end

  def recalculate
    self.cost = if dynamic
                  dynamic_cost
                else
                  unit_cost && count ? unit_cost * count : 0
                end

    self
  end

  def recalculate_invoice!
    invoice.recalculate!
  end

  def vat
    vat_rate ? self.cost * (vat_rate / 100) : 0
  end
end
