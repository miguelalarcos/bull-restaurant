class ValidateItem

  def self.validate_display txt, doc=nil
    txt.length >= 2
  end

  def self.validate_price price, doc=nil
    price.is_a?(Numeric) && price >= 0.0
  end

  def self.validate doc
    self.validate_price(doc[:price], doc) && self.validate_display(doc[:display], doc)
  end
end