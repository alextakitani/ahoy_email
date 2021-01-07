class ExtraMailer < ApplicationMailer
  save_history
  save_history extra: {coupon_id: 1}, only: [:basic]
  save_history extra: -> { {coupon_id: @coupon_id} }, only: [:dynamic]

  def welcome
    mail
  end

  def basic
    mail
  end

  def dynamic(coupon_id)
    @coupon_id = coupon_id
    mail
  end
end
