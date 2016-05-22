require 'ui_core'
require 'reactive-ruby'
require 'reactive_var'
require 'validation/validation'
require 'notification'
require 'set'

def format_float_sup_money value, symb
  integer, decimal = format_float(value).split('.')
  span do
    span{integer}
    sup{'.' + decimal} if !decimal.nil?
    span{symb}
  end
end

class SelectTable < DisplayList
  param :set_order, type: Proc

  before_mount do
    watch_ 'tables_opened', []
  end

  def render
    div do
      SelectObjectInput(display: 'table', options: state.docs.sort{|a,b| a['table'].to_i <=> b['table'].to_i},
                        on_change: lambda{|v| params.set_order v['order_id']})
    end
  end
end

class WaiterNotification < DisplayList
  param :waiter
  param :set_order, type: Proc

  before_mount do
    watch_ 'waiter_notifications', params.waiter, []
  end

  def render
    groups = state.docs.group_by{|x| {order_id: x['order_id'], table: x['table']} }
    div do
      groups.each_pair do |k, lines|
        div do
          span{k[:table]}.on(:click){params.set_order k[:order_id]}
          a(href: '#'){'done'}.on(:click){$controller.task('done', k[:order_id])}
        end
      end
    end
  end
end

class ProductMenu < React::Component::Base
  param :table
  param :order_id
  param :waiter
  param :order_list

  before_mount do
    path = RVar.new 'root'
    reactive(path) do
      $controller.rpc('products', path.value).then do |products|
        state.products = products
      end
    end
  end

  def add_product product, price
    line = params.order_list.select{|x| x['name']==product}
    if line.empty?
      $controller.insert('line', {:table=>params.table, :order_id=>params.order_id, :product=>product, :quantity=>1,
                                  :price=> price, :waiter=>params.waiter})
    else
      $controller.update('line', line[0]['id'], {:quantity=>line[0]['quantity']+1})
    end
  end

  def render
    div do
      a(href: '#'){'home'}.on(:click){@path.value = 'root'}
      state.products.each do |doc|
        a(href: '#'){doc['name']}.on(:click) do
          if doc['is_product']
            add_product doc['name'], doc['price']
          else
            @path.value = doc['path']
          end
        end
      end
    end
  end
end

class Total < DisplayDoc
  param :order_id

  before_mount do
    watch_ 'order', params.order_id
  end

  def render
    span do
      format_float_sup_money state.total, '€'
    end
  end
end

class WaiterPage < DisplayList
  param :waiter
  param :show

  before_mount do
    state.order_id! nil
    state.table! nil
    watch_ 'watch_table', state.order_id, []
  end

  def remove_product line_id, quantity
    if quantity > 1
      $controller.update('line', line_id, {:quantity=>quantity-1})
    else
      $controller.delete('line', line_id)
    end
  end

  def render
    div(class: params.show ? '': 'no-display') do
      WaiterNotification(key: 'waiter_notification', waiter: params.waiter,
                         set_order: lambda{|v| state.order_id! v})
      SelectTable(set_order: lambda{|v| state.order_id! v})
      button{'Nueva mesa'}.on(:click) do
        $controller.rpc('new_table', params.waiter).then do |response|
          state.order_id! response[0]
          state.table! response[1]
        end
      end
      ProducMenu(table:state.table, order_id: state.order_id, waiter: params.waiter,
                 order_list: state.docs.select{|x| x['status'] == 'draft'})
      state.docs.select{|x| x['status'] == 'draft'}.each do |doc|
        div do
          span{doc['product']}
          span{' : '}
          span{doc['quantity']}
          span{'-'}.on(:click){remove_product doc['id'], doc['quantity']}
        end
      end
      state.docs.select{|x| x['status'] == 'kitche_done'}.each do |doc|
        div do
          span{doc['product']}
          span{' : '}
          span{doc['quantity']}
        end
      end
      state.docs.select{|x| x['status'] == 'done'}.each do |doc|
        div do
          span{doc['product']}
          span{' : '}
          span{doc['quantity']}
          span{' : '}
          span{doc['price']}
          span{' : '}
          span{(doc['quantity']*doc['price']).to_s}
        end
      end
      Total(order_id: state.order_id)
      button{'Cerrar'}.on(:click){$controller.task('close_order', state.order_id)}
    end
  end
end

class KitchenTable < DisplayList
  param :table
  param :docs

  def render
    div do
      params.docs.each do |doc|
        div do
          span{params.table}
          span{'hecho'}.on(:click){$controller.task('kitchen_done', doc['order_id'])}
        end
        div do
          span{doc['product']}
          span{' : '}
          span{doc['quantity']}
          span{'hecho'}.on(:click){$controller.task('kitchen_line_done', doc['id'])}
        end
      end
    end
  end
end

class KitchenPage < DisplayList
  param :show

  before_mount do
    watch_ 'kitchen', []
  end

  def render
    groups = state.docs.group_by{|x| x['table']}
    div(class: params.show ? '': 'no-display') do
      groups.each_pair do |k, docs|
        KitchenTable(table: k, docs: docs)
      end
    end
  end
end

class App < React::Component::Base

  before_mount do
    state.user! 'camarero' #nil
    state.roles! []
    state.page! 'waiter'
  end

  def render
    div do
      Notification(level: 0)
      HorizontalMenu(page: state.page, set_page: lambda{|v| state.page! v},
                     options: {:waiter=>'Camarero', :kitchen=>'Cocina'})
      WaiterPage(key: 'waiter-page', show: state.page == :waiter, waiter: state.user)
      KitchenPage(key: 'kitchen-page', show: state.page == :kitchen)
    end
  end
end

