require 'ui_core'
require 'reactive-ruby'
require 'reactive_var'
#require 'validation/validation'
require 'notification'
require 'set'
require 'time'

def format_float_sup_money value, symb
  integer, decimal = format_float(value).split('.')
  span do
    span{integer}
    sup{'.' + decimal} if !decimal.nil?
    span{symb}
  end
end

class SelectTable < DisplayList
  param :set, type: Proc

  before_mount do
    watch_ 'tables_opened', []
  end

  def render
    div do
      SelectObjectInput(display: 'table', options: state.docs.sort{|a,b| a['table'] <=> b['table']},
                        on_change: lambda{|v| params.set v})
    end
  end
end

class WaiterNotification < DisplayList
  param :waiter
  param :set, type: Proc

  before_mount do
    watch_ 'waiter_notifications', params.waiter, []
  end

  def render
    groups = state.docs.group_by{|x| {order_id: x['order_id'], table: x['table'], scope: x['scope']} }
    div do
      groups.each_pair do |k, lines|
        div(key: k[:table]+':'+k[:scope]) do
          audio(autoplay: true){source(src:'push.mp3', type:'audio/mpeg')}
          span{k[:table] + ' ' + k[:scope]}.on(:click){params.set k}
          a(href: '#'){'hecho'}.on(:click){$controller.task('done', k[:order_id], k[:scope])}
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
    $controller.rpc('products').then do |products|
      state.products! products
    end
    state.path! 'root'
    state.prefix! ''
  end

  def add_product product, price, scope
    line = params.order_list.select{|x| x['name']==product}
    if line.empty?
      $controller.insert('line', {:table=>params.table, :order_id=>params.order_id, :product=>product, :quantity=>1,
                                  :price=> price, :waiter=>params.waiter, :scope=>scope, timestamp: Time.now})
    else
      $controller.update('line', line[0]['id'], {:quantity=>line[0]['quantity']+1})
    end
  end

  def render
    div do
      div do
        StringInput(value: state.prefix, on_change: lambda{|v| state.prefix! v})
        button{'x'}.on(:click){state.prefix! ''}
      end
      a(href: '#'){'home'}.on(:click){@path.value = 'root'}
      if state.prefix != ''
        products = state.products.select{|x| x['name'].start_with? state.prefix}
      else
        products = state.products.select{|x| x['path'] == state.path}
      end
      products.each do |doc|
        a(href: '#'){doc['name']}.on(:click) do
          if doc['is_product']
            add_product doc['name'], doc['price'], doc['scope']
          else
            state.path! doc['path'] + '.' + doc['name']
          end
        end
      end
    end
  end
end

class Total < DisplayDoc
  param :order
  @@table = 'order'

  before_mount do
    watch_ params.order
  end

  def clear
    state.total! 0.0
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

  include MNotification

  before_mount do
    @order = RVar.new nil
    #state.order_id! nil
    state.table! nil
    state.new_table! nil
    watch_ 'watch_table', @order.value, [@order] # state.order_id, []
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
                         set: lambda{|v| @order.value= v['order_id']; state.table! v[:table]})
      SelectTable(key: 'select-table', set: lambda{|v| @order.value= v['order_id']; state.table! v['table']})
      StringInput(value: state.new_table, on_change: lambda{|v| state.new_table! v})
      button{'Nueva mesa'}.on(:click) do
        $controller.rpc('new_table', params.waiter, state.new_table).then do |response|
          if response.nil?
            notify_error 'Ya hay una mesa activa con ese código.', 1
          else
            #state.order_id! response
            @order.value = response
            state.table! state.new_table
          end
        end
      end
      h2{state.table}
      ProducMenu(key: 'product-menu', table:state.table, order_id: @order.value, waiter: params.waiter,
                 order_list: state.docs.select{|x| x['status'] == 'draft'}) if !state.table.nil?
      div(key: 'order-lines') do
        state.docs.select{|x| x['status'] == 'draft'}.each do |doc|
          div(key: 'draft'+doc['id']) do
            span{doc['product']}
            span{' : '}
            span{doc['quantity']}
            span{'-'}.on(:click){remove_product doc['id'], doc['quantity']}
          end
        end
      end
      button{'Enviar'}.on(:click){$controller.task('send', @order.value)}
      div(key: 'bar-ready') do
        h2{'Preparado en la barra'}
        state.docs.select{|x| x['status'] == 'bar_done'}.each do |doc|
          div(key: 'bar-ready'+doc['id']) do
            span{doc['product']}
            span{' : '}
            span{doc['quantity']}
          end
        end
      end
      div(key: 'kitchen-ready') do
        h2{'Preparado en cocina'}
        state.docs.select{|x| x['status'] == 'kitche_done'}.each do |doc|
          div(key: 'kitchen-ready'+doc['id']) do
            span{doc['product']}
            span{' : '}
            span{doc['quantity']}
          end
        end
      end
      div(key: 'order') do
        h2{'Factura'}
        state.docs.select{|x| x['status'] == 'done'}.each do |doc|
          div(key: 'order'+doc['id']) do
            span{doc['product']}
            span{' : '}
            span{doc['quantity']}
            span{' : '}
            span{doc['price']}
            span{' : '}
            span{(doc['quantity']*doc['price']).to_s}
          end
        end
      end
      Total(key: 'total', order: @order)
      button{'Cerrar'}.on(:click){$controller.task('close_order', @order.value)} if !state.table.nil?
    end
  end
end

class KitchenTable < DisplayList
  param :table
  param :docs
  param :order_id

  def render
    div do
      div do
        span{params.table}
        span{'hecho'}.on(:click){$controller.task('kitchen_done', params.order_id)}
      end
      params.docs.each do |doc|
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
    ret = []
    groups = state.docs.group_by{|x| {'table'=>x['table'], 'order_id'=>x['order_id']}}
    groups.each_pair do |k, docs|
      ret << {'table'=>k['table'], 'order_id'=>k['order_id'], 'timestamp'=>docs[0]['timestamp'], 'docs'=>docs}
    end
    ret.sort{|a,b| a['timestamp'] <=> b['timestamp']}
    div(class: params.show ? '': 'no-display') do
      #groups.each_pair do |k, docs|
      ret.each do |item|
        #KitchenTable(table: k[:table], order_id: k[:order_id], docs: docs)
        KitchenTable(table: item['table'], order_id: item['order_id'], docs: item['docs'])
      end
    end
  end
end

class BarTable < DisplayList
  param :table
  param :docs
  param :order_id

  def render
    div do
      div do
        span{params.table}
        span{'hecho'}.on(:click){$controller.task('bar_done', params.order_id)}
      end
      params.docs.each do |doc|
        div do
          span{doc['product']}
          span{' : '}
          span{doc['quantity']}
        end
      end
    end
  end
end

class BarPage < DisplayList
  param :show

  before_mount do
    watch_ 'bar', []
  end

  def render
    # ordenar como en kitchen
    groups = state.docs.group_by{|x| {table: x['table'], order_id: x['order_id']}}
    div(class: params.show ? '': 'no-display') do
      groups.each_pair do |k, docs|
        BarTable(table: k[:table], order_id: k[:order_id], docs: docs)
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
                     options: {:bar=>'Bar', :waiter=>'Camarero', :kitchen=>'Cocina'})
      #BarPage(key: 'bar-page', show: state.page == :bar)
      WaiterPage(key: 'waiter-page', show: state.page == :waiter, waiter: state.user)
      #KitchenPage(key: 'kitchen-page', show: state.page == :kitchen)
    end
  end
end

