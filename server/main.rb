$LOAD_PATH.unshift '../../bull-rb'
$LOAD_PATH.unshift '../../app'
require 'server/server'
require 'server/start'
require 'conf'
require 'bigdecimal'

class AppController < BullServerController

  def before_insert_line doc
    true
  end

  def before_update_line old, new, merged
    true
  end

  def rpc_products path
    check path, String
    rmsync $r.table('products').filter('path'=>path)
  end

  def rpc_new_table waiter
    check waiter, String
    orders = rmsync $r.table('order').filter('status'=>'opened')
    tables = orders.collect{|x| x['table']}.sort
    new_table = 1
    for table in tables
      if new_table != table
        break
      end
      new_table += 1
    end
    ret = rsync $r.table('order').insert(status: 'opened', waiter: waiter, table: new_table.to_s, datetime: Time.now, total: 0.0)
    ret['generated_keys'][0]
  end

  def task_send_to_kitchen order_id
    check order_id, String
    rsync $r.table('line').filter('order_id'=>order_id, 'status'=>'draft').update('status'=>'kitchen')
  end

  def task_kitchen_done line
    check line, String
    rsync $r.table('line').get(line).update('status'=>'kitchen_done')
  end

  def task_done order_id
    check order_id, String
    rsync $r.table('line').filter('order_id'=>order_id, 'status'=>'kitchen_done').update('status'=>'done')
    lines = rmsync $r.table('line').filter('order_id'=>order_id, 'status'=>'done')
    total = lines.inject(BigDecimal('0')){|sum, n| sum + BigDecimal(n['price'])*BigDecimal(n['quantity'])}
    rsync $r.table('order').get(order_id).update({'status'=>'closed', 'total'=> total.to_f})
  end

  def watch_waiter_notifications waiter
    check waiter, String
    $r.table('line').filter('status'=> 'kitchen_done', 'waiter'=>waiter)
  end

  def watch_tables_opened
    $r.table('order').filter('status'=>'opened')
  end

  def watch_table order_id
    check order_id, String
    $r.table('line').filter('order_id'=>order_id)
  end

  def watch_kitchen
    $r.table('line').filter('status'=>'kitchen')
  end

end

start AppController