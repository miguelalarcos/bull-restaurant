$LOAD_PATH.unshift '../../bull-rb'
$LOAD_PATH.unshift '../../app'
require 'server/server'
require 'server/start'
require 'conf'

class AppController < BullServerController

  def rpc_products path
    check path, String
    rmsync $r.table('products').filter('path'=>path)
  end

  def rpc_add_product order_id, product, waiter
    check order_id, String
    check product, String
    how_many = rsync $r.table('line').filter('order_id'=>order_id, 'product'=>product).count
    if how_many == 0
      rsync $r.table('line').insert('order_id'=>order_id, 'product'=>product, 'quantity'=>1, 'waiter'=>waiter)
    else
      rsync $r.table('line').filter('order_id'=>order_id, 'product'=>product).update do |doc|
        {:quantity => doc['quantity'] + 1}
      end
    end
  end

  def rpc_remove_product order_id, product
    check order_id, String
    check product, String
    how_many = rsync $r.table('line').filter('order_id'=>order_id, 'product'=>product).count
    if how_many > 1
      rsync $r.table('line').filter('order_id'=>order_id, 'product'=>product).update do |doc|
        {:quantity => doc['quantity'] - 1}
      end
    else
      rsync $r.table('line').filter('order_id'=>order_id, 'product'=>product).delete
    end
  end

  def rpc_new_table

  end

  #def rpc_create_table table
  #  check table, String
  #  how_many = rsync $r.table('table').filter('name'=>table).count
  #  if how_many == 0
  #    rsync $r.table('table').insert('name'=>table)
  #  end
  #end

  def task_send_to_kitchen order_id
    check table, String
    rsync $r.table('line').filter('order_id'=>order_id, 'status'=>'draft').update('status'=>'kitchen')
  end

  def task_kitchen_done line
    check line, String
    rsync $r.table('line').get(line).update('status'=>'kitchen_done')
  end

  def task_done order_id
    check table, String
    rsync $r.table('line').filter('order_id'=>order_id, 'status'=>'kitchen_done').update('status'=>'done')
  end

  def watch_waiter_notifications waiter
    check waiter, String
    $r.table('line').filter('status'=> 'kitchen_done', 'waiter'=>waiter)
  end

  def watch_tables
    $r.table('table')
  end

  def waiter_table_draft order_id
    check table, String
    $r.table('line').filter('status'=>'draft', 'order_id'=>order_id)
  end

  def watch_kitchen
    $r.table('line').filter('status'=>'kitchen')
  end

end

start AppController