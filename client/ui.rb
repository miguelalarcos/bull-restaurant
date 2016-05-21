require 'ui_core'
require 'reactive-ruby'
require 'reactive_var'
require 'validation/validation'
require 'notification'

def format_float_sup_money value, symb
  integer, decimal = format_float(value).split('.')
  span do
    span{integer}
    sup{'.' + decimal} if !decimal.nil?
    span{symb}
  end
end

class SelectTable < DisplayList
  param :table

  before_mount do
    watch_ 'tables', []
  end

  def render
    div do
      SelectInput(options: state.docs.collect{|doc| doc['table']}, on_change: lambda{|v| params.table.value = v})
    end
  end
end

class CreateTable < React::Component::Base
  param :table

  before_mount do
    state.name! ''
  end

  def render
    div do
      StringInput(on_change: lambda{|v| state.name! v})
      button{'Nueva mesa'}.on(:click) do
        $controller.rpc('create_table', state.name).then do |response|
          params.table.value = state.name if response
        end
      end
    end
  end
end

class SelectCreateTable < React::Component::Base
  param :table

  def render
    div do
      CreateTable(table: params.table)
      SelectTable(table: params.table)
    end
  end
end

class WaiterNotification < DisplayList
  param :waiter

  before_mount do
    watch_ 'waiter_notifications', params.waiter, []
  end

  def render
    tables = state.docs.collect{|x| x['table']}.uniq
    div do
      tables.each do |table|
        div{table}
      end
    end
  end
end

class ProductMenu < React::Component::Base
  param :order_id #:table
  param :waiter

  before_mount do
    path = RVar.new 'root'
    reactive(path) do
      $controller.rpc('products', path.value).then do |products|
        @products = products
      end
    end
  end

  def render
    div do
      @products.each do |doc|
        a(href: '#'){doc['name']}.on(:click) do
          if doc['is_product']
            $controller.rpc 'add_product', params.order_id, doc['name'], params.waiter
          else
            @path.value = doc['path']
          end
        end
      end
    end
  end
end

class WaiterPage < DisplayList
  param :waiter
  param :show

  before_mount do
    #@table = RVar.new nil
    state.order_id! nil
    watch_ 'waiter_table_draft', @table.value, [@table]
  end

  def render
    div(class: params.show ? '': 'no-display') do
      WaiterNotification(key: 'waiter_notification', waiter: params.waiter)
      #SelectCreateTable(table: @table)
      button{'Nueva mesa'}.on(:click) do
        $controller.rpc('new_table').then {|response| state.order_id! response}
      end
      #ProducMenu(table: @table.value, waiter: params.waiter)
      ProducMenu(order_id: state.order_id, waiter: params.waiter)
      state.docs.each do |doc|
        div do
          span{doc['product']}
          span{' - '}
          span{doc['quantity']}
        end
      end
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
          span{doc['product']}
          span{' - '}
          span{doc['quantity']}
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
    state.user! nil
    state.roles! []
    state.page! 'waiter'
  end

  def render
    div do
      Notification(level: 0)
      HorizontalMenu(page: state.page, set_page: lambda{|v| state.page! v},
                     options: {'waiter'=>'Camarero', 'kitchen'=>'Cocina'})
      #PageTables(key: 'page-tables', show: state.page == 'tables')
      WaiterPage(key: 'waiter-page', show: state.page == 'waiter', waiter: state.user)
      KitchenPage(key: 'kitchen-page', show: state.page == 'kitchen')
    end
  end
end
