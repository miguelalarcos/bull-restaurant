require 'ui_core'
require 'reactive-ruby'
require 'reactive_var'
require 'validation/validation-item'
require 'notification'

class TextArea2Array < React::Component::Base
  param :data
  param :on_change, type: Proc

  before_mount do
    state.value! ''
  end

  def render
    txt = params.data.join "\n"
    div do
      MultiLineInput(value: txt, on_change: lambda{|v| state.value! v})
      button{'Guardar'}.on(:click){params.on_change state.value.split("\n")}
    end
  end
end

class EditGrouper < React::Component::Base
  param :doc

  before_mount do
    state.display! nil
    state.items! []
  end

  def render
    div do
      div{StringInput(placeholder: 'display', value: state.display || params.doc['display'], on_change: lambda{|v| state.display! v})}
      div{TextArea2Array(data: params.doc['items'], on_change: lambda{|v| state.items! v})}
    end
  end
end

class EditItem < React::Component::Base

  param :doc

  before_mount do
    state.display! params.doc['display'] # nil
    state.price! params.doc['price']
    state.background_color! params.doc['background-color'] # nil
    state.color! params.doc['color'] #'black'
  end

  def item
    {display: state.display, price: state.price, 'background-color' => state.background_color, color: state.color}
  end

  def render
    div do
      div{StringInput(placeholder: 'display', value: state.display, on_change: lambda{|v| state.display! v})}
      div{FloatInput(placeholder: 'precio', value: state.price, on_change: lambda{|v| state.price! v})}
      div(class: 'red'){'El precio debe ser un número positivo'} if !ValidateItem.validate_price state.price
      div{input(type: :color).on(:change){|event| state.background_color! event.target.value}}
      RadioInput(value: state.color, values: ['white', 'black'], name: 'color', on_change: lambda{|v| state.color! v})
      div{button{'Guardar'}.on(:click) do
        hsh = item
        $controller.update('item',  params.doc['id'], hsh)
      end} if ValidateItem.validate item
    end
  end

end

class GrouperAdministration < DisplayList

  before_mount do
    state.new_item! nil
    state.edit_item! nil
    watch_ 'groupers'
  end

  def render
    div do
      div(class: 'flex-item') do
        StringInput(placeholder: 'display', value: state.new_item, on_change: lambda{|v| state.new_item! v})
        button{'Nuevo'}.on(:click) do
          slug = state.new_item.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
          hsh = {code: slug, type: 'grouper', display: state.new_item}
          $controller.insert('item', hsh)
        end if state.new_item != ''
        state.docs.each do |doc|
          div(key: doc['id']) do
            span(style: {'backgroundColor' => 'green', 'color' => 'white'}){doc['display']}
            a(href: '#'){'editar'}.on(:click){state.edit_item! doc['code']}
          end
          EditGrouper(doc: doc) if state.edit_item == doc['code']
        end
      end
    end
  end
end

class ItemAdministration < DisplayList

  before_mount do
    state.new_item! ''
    state.edit_item! nil
    state.search! ''
    @search = RVar.new ''
    watch_ 'items_by_pattern', @search #, [@search]
  end

  def item
    slug = state.new_item.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    {code: slug, type: 'item', display: state.new_item, price: 0.0, complements: []}
  end

  def render
    div(class: 'flex-item') do
      StringInput(placeholder: 'display', value: state.new_item, on_change: lambda{|v| state.new_item! v})
      div(class: 'red'){'La longitud del texto debe ser al menos de 2 caracteres'} if !ValidateItem.validate_display state.new_item
      button{'Nuevo'}.on(:click) do
        slug = state.new_item.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
        hsh = {code: slug, type: 'item', display: state.new_item, price: 0.0, complements: []}
        $controller.insert('item', hsh)
        @search.value = slug
        state.search = slug
      end if ValidateItem.validate item
      StringInput(placeholder: 'búsqueda', value: state.search, on_change: lambda{|v| @search.value = v; state.search! v})
      state.docs.each do |doc|
        div(key: doc['id']) do
          span(style: {'backgroundColor' => doc['background-color'], 'color' => doc['color']}){doc['display']}
          a(href: '#'){'editar'}.on(:click){state.edit_item! doc['code']}
        end
        EditItem(doc: doc) if state.edit_item == doc['code']
      end #if state.search.length >= 2
    end
  end
end

class ItemInput < React::Component::Base
  before_mount do
    $controller.rpc('items').then do |docs|
      print docs
    end
  end

  def render
    div do
      'Item Input'
    end
  end
end

=begin
class Item < React::Component::Base
  param :data
  param :click, type: Proc

  def render
    span(style: {backgroundcolor: params.data['backgroundcolor'], color: params.data['color']}) do
      params.data['display']
    end.on(:click) do
      params.click params.data['code']
    end
  end
end

class FinalView < React::Component::Base
  param :data

  before_mount do
    state.path! 'root'
  end

  def click v
    if params.data[v]['type'] == 'grouper'
      state.path! v
    end
  end

  def render
    gr = params.data[state.path]
    items = gr['items'] || []
    div(class: 'flex-container') do
      Item(data: params.data['root'], click: lambda{|v| click v})
      items.each do |item|
        Item(data: params.data[item], click: lambda{|v| click v})
      end
    end
  end
end
=end

class Administration < React::Component::Base

  def render
    div(class: 'flex-container') do
      ItemAdministration()
      GrouperAdministration()
      ItemInput()
    end
  end
end

class App < React::Component::Base

  def render
    div do
      Notification(level: 0)
      Administration()
    end
  end
end

