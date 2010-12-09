class TextileArticle < TextArticle

  def self.short_description
    _('Text article with Textile markup language')
  end

  def self.description
    _('Accessible alternative for visually impaired users.')
  end

  def to_html(options ={})
    RedCloth.new(self.body|| '').to_html
  end

  def notifiable?
    true
  end

  def translatable?
    true
  end

end
