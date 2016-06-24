require 'ui_core'
require 'reactive-ruby'
require 'reactive_var'
require 'validation/validation-item'
require 'notification'

class TextArea2Array < React::Component::Base
  param :data
  param :on_change, type: Proc

  before_mount do
    state.value! (params.data || []).join "\n"
  end

  def render
    #data = params.data || []
    #txt = data.join "\n"
    div do
      MultiLineInput(value: state.value, on_change: lambda{|v| state.value! v})
      button{'Set'}.on(:click){params.on_change state.value.split("\n")}
    end
  end
end

class EditGrouper < React::Component::Base
  param :doc

  before_mount do
    state.display! params.doc['display']
    state.items! params.doc['items']
  end

  def grouper
    {display: state.display, items: state.items}
  end

  def render
    div do
      div{StringInput(placeholder: 'display', value: state.display || params.doc['display'], on_change: lambda{|v| state.display! v})}
      div{TextArea2Array(data: params.doc['items'], on_change: lambda{|v| state.items! v})}
      div{button{'Guardar'}.on(:click) do
        $controller.update('item',  params.doc['id'], grouper)
      end}
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

class WaiterPage < React::Component::Base

  before_mount do
    @order = RVar.new nil
    state.table! nil
    #state.table_tmp! nil
  end

  def item_clicked item
    $controller.insert('line', {order_id: @order.value, type: 'carta', code: item['code'], status: 'draft',
                                display: item['display'], price: item['price']}) unless @order.value.nil?
  end

  def render
    div do
      h1{state.table}
      Tables(clicked: lambda{|order_id, table| @order.value = order_id; state.table! table})
      ItemInput(item_clicked: lambda{|x| item_clicked x})
      DraftItemsArray(order: @order)
    end
  end
end

class Tables < DisplayList

  param :clicked, type: Proc

  before_mount do
    watch_ 'tables'
    state.show! true
  end

  def occupied
    state.docs.inject({}) do |hash, x|
      hash[x['table']] = x['id']
      hash
    end
  end

  def occupied_class tables, table
    if tables[table].nil?
      'table-green'
    else
      'table-red'
    end
  end

  def animation
    if state.show
      'animated fadeInDown'
    else
      'animated fadeOutUp'
    end
  end

  def render
    tables = occupied
    div do
      div{'Mesas'}.on(:click){state.show! !state.show}
      #div(class: animation) do
      div do
        ['1', '2', '3'].each do |table|
          span(class: occupied_class(tables, table)){table}.on(:click) do
            if tables[table].nil?
              $controller.insert('order', {active: true, table: table}).then do |order_id|
                state.show! false
                params.clicked order_id, table
              end
            else
              state.show! false
              params.clicked tables[table], table
            end
          end
        end
      end if state.show
    end
  end
end

class ItemInput < React::Component::Base
  param :item_clicked, type: Proc

  before_mount do
    state.path! 'root'
    @items = {}
    $controller.rpc('items').then do |docs|
      docs.each do |x|
        @items[x['code']] = x
      end
    end
  end

  def items path
    if @items[path].nil?
      []
    else
      @items[path]['items']
    end
  end

  def display code
    @items[code]['display']
  end

  def style code
    {'backgroundColor'=>@items[code]['background-color'], 'color'=>@items[code]['color']}
  end

  def grouper? code
    @items[code]['type'] == 'grouper'
  end

  def render
    div do
      span{'Inicio'}.on(:click) do
        state.path! 'root'
      end
      items(state.path).each do |item_code|
        span(style: style(item_code)){display(item_code)}.on(:click) do
          if grouper?(item_code)
            state.path! item_code
          else
            params.item_clicked @items[item_code]
          end
        end
      end
    end
  end
end

class DraftItemsArray < DisplayList

  param :order

  before_mount do
    watch_ 'table_draft', params.order
  end

  def render
    gr = state.docs.select{|x| x['type'] == 'carta'}.group_by{|x| {display: x['display']}}
    div do
      table do
        tr do
          th{'Item'}
          th{'Cantidad'}
          th{' '}
        end
        gr.each_pair do |k, v|
          tr do
            td{k[:display]}
            td{v.length.to_s}
            td{'-'}.on(:click) do
              line_id = v[0]['id']
              $controller.delete('line', line_id)
            end
          end
        end
      end
      div{'Enviar'}#.on(:click){$controller.task('send')}
    end
  end
end

class Administration < React::Component::Base

  def render
    div(class: 'flex-container') do
      ItemAdministration()
      GrouperAdministration()
      WaiterPage()
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

