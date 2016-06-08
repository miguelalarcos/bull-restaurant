require 'ui_core'
require 'reactive-ruby'
require 'reactive_var'
require 'validation/validation-item'
require 'notification'

class EditItem < React::Component::Base

  param :code
  param :values

  before_mount do
    state.display! nil
    state.price! nil
  end

  def render
    div do
      StringInput(value: state.display || params.values['display'], on_change: lambda{|v| state.display! v})
      FloatInput(value: state.price || params.values['price'], on_change: lambda{|v| state.price! v})
      span(class: 'red'){'El precio debe ser un número positivo'} if !ValidateItem.validate_price state.price
      button{'Guardar'}.on(:click) do
        hsh = Hash.new
        hsh[params.code] = {display: state.display, price: state.price}
        $controller.update('item', 'item-restaurant-101', hsh)
      end
    end
  end

end

class ItemAdministration < React::Component::Base

  param :items

  before_mount do
    state.new_item! nil
    state.edit_item! nil
  end

  def render
    div do
      StringInput(value: state.new_item, on_change: lambda{|v| state.new_item! v})
      button{'Nuevo'}.on(:click) do
        hsh = Hash.new
        slug = state.new_item.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
        hsh[slug] = {type: 'item', display: state.new_item, price: nil, complements: []}
        $controller.update('item', 'item-restaurant-101', hsh)
      end if state.new_item != ''
      params.items.each_pair do |k, v|
        div do
          span{k}
          span{v['price']}
          a(href: '#'){'editar'}.on(:click){state.edit_item! k}
        end
        EditItem(code: k, values: v) if state.edit_item == k
      end
    end
  end
end

class App < React::Component::Base

  before_mount do
    @predicate_id = $controller.watch('item', 'item-restaurant-101') do |data|
      state.doc! data['items']
    end
  end

  def items
    state.doc.select{|k, v| v['type'] == 'item'}
  end

  def render
    div do
      Notification(level: 0)
      ItemAdministration(items: items)
    end
  end

  before_unmount do
    $controller.stop_watch @predicate_id if @predicate_id != nil
  end

end