$LOAD_PATH.unshift '../../bull-rb'
$LOAD_PATH.unshift '../../app'
require 'server/server'
require 'server/start'
require 'conf'
require 'bigdecimal'
require 'time'

class AppController < BullServerController

  def initialize ws, conn
    super ws, conn
    @sent_code = 0
  end

  def before_insert_line doc
    true
  end

  def before_update_line old, new, merged
    true
  end

  def after_insert_line doc
    puts 'after insert line'
  end

  def after_update_line doc
    puts 'after update line'
  end

  def before_delete_line doc
    true
  end

=begin
  def rpc_products
    #check path, String
    rmsync $r.table('product')
  end
=end

  def sent_code
    @sent_code += 1
    @sent_code.to_s
  end

  def task_send order_id
    check order_id, String
    rsync $r.table('line').filter(:order_id=>order_id, :status=>'draft').update(:status=>'sent'+sent_code)
  end

  def task_done order_id, code
    check order_id, String
    check code, String
    rsync $r.table('line').filter(:order_id=>order_id, :status=>code).update(:status=>'done')
  end

  def total order_id
    lines = rmsync $r.table('line').filter(:order_id=>order_id, :status=>'done')
    total = lines.inject(BigDecimal('0')){|sum, n| sum + BigDecimal(n['price'])*BigDecimal(n['quantity'])}
    rsync $r.table('order').get(order_id).update({:total=> total.to_f})
  end

  def task_close_order order_id
    check order_id, String
    rsync $r.table('order').get(order_id).update({:status=> 'closed'})
  end

  def watch_order order_id
    check order_id, String
    if order_id.nil?
      nil
    else
      $r.table('order').get(order_id)
    end
  end

  def watch_table order_id
    check order_id, String
    $r.table('line').filter(:order_id=>order_id)
  end

end

start AppController