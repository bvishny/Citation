# This provides activerecord-like properties for TokyoTyrant Table

# IMPORTANT: YOU MUST INITIALIZE $db before using this class! 
# DO SO AS FOLLOWS:
# require 'tokyo_tyrant'
#  $db = TokyoTyrant::Table.new('ip', 1978)
  
class TokyoRecord
  require 'uuidtools'
  require 'active_support'
  
  # Key is primary key
  attr_reader :key
  attr_accessor :data
  
  # This error is triggered when $db is not defined
  class TyrantError < StandardError
  end
  
  # CRUD
  def initialize(options = {})
    @data, @key = {'table' => self.class.to_s}, options[:pk] # nil for a new record
    merge(options)
  end
  
  def save
    time = Time.now.to_i # Store current time
    (@key, @data["created_at"] = UUIDTools::UUID.timestamp_create.to_s, time) if new? # Stamp, ID record if new
    @data["updated_at"] = time # Timestamp each time saved
    $db[@key] = @data # Set KEY, VALUE
  end
  
  alias :save! :save
  
  # END GROUP CREATE
  def update_attributes(params = {})
    params.each { |key, value| @data[key.to_s] = value }
    $db[@key] = @data
  end
  # GROUP UPDATE
  
  # Destroy
  def destroy
    $db.delete(@key)
  end
  
  # GROUP PROPERTIES
  def table
    ($db.nil? or !$db.is_a?(TokyoTyrant::Table)) ? (raise TyrantError, "Tyrant is not connected"): $db
  end

  def connected?
    !$db.nil?
  end
  
  def new?
    @key.nil?
  end

  def blank?
   self.nil?
  end
  
  def ==(obj)
    obj.equal?(self) or (obj.instance_of?(self.class) and obj.key == @key and !obj.new?)
  end
  # END GROUP PROPERTIES

  # GROUP METHOD MISSING
  def method_missing(key, *args)
    if (name = key.to_s)[-1, 1] == "=" 
      @data[name.chop.to_s] = args.first
    else
      (@data.keys.include? name) ? (@data[text].instance_eval((name[-2, 2] == "id") ? "to_i" : "self")) : super
    end
  end
  
  # Supports the following functions:
  # find_by_field1_and_field2_and_field3 etc
  # find_all_by_field1_and_field2_and_field3 etc
  # find_or_create_by_field1_and_field2_and_field3
  def self.method_missing(key, *args)
    if (name = key.to_s)[0, 5] == "find_" # Flexible find methods
      limit, attributes, q = name.include? "find_all", name.gsub(/find_(all_by|by|or_create_by)_/, "").split("_and_"), connected?($db).query
      attributes.zip(args) { |f, x| 
        q.condition("table", :streq, self.name.to_s)
        q.condition(f, (op = (x.is_a? Fixnum) ? :numeq : :streq), x) 
      }
      q.limit(1) if limit
      result = q.search.zip(q.get).map { |k, v| new(v.merge(:pk => k))}
      (result.empty? and name.include? "or_create_by") ? new(Hash[*attributes.zip(args).flatten]) : ((limit) ? result[0] : result)
    end
  end
  # END GROUP METHOD MISSING
  
  # GROUP RELATIONS
  
  # RELATIONS
  def self.belongs_to(table, params = {})
    define_method(method = (params[:class_name] ||= table.to_s.underscore)) do
      method.camelize.constantize.find_by_key(self.send(params[:foreign_key].to_s ||= (method + "_id")))
    end
  end
  
  def self.has_one(table, params = {})
    define_method(method = (params[:class_name] ||= table.to_s.underscore)) do
      method.camelize.constantize.find(:first, 
      :conditions => ["#{params[:foreign_key] ||= (self.class.to_s.underscore + "_id")} = ?#{params[:conditions] ? " and #{params[:conditions]}" : ""}", self.key])
    end
  end
  
  def has_many(table, params = {}) # has_many :through works!
    define_method(method = (params[:class_name] ||= table.to_s.pluralize.underscore)) do
      if params[:through]
        params[:through].to_s.singularize.camelize.constantize.find(:all, 
        :conditions => ["#{params[:foreign_key] ||= (self.class.to_s.underscore + "_id")} = ?#{params[:conditions] ? " and #{params[:conditions]}" : ""}", self.key]).collect { |ref|
           method.camelize.constantize.find_by_key(ref.send(params[:primary_key] ||= (method + "_id")))
        }
      else
        method.camelize.constantize.find(:all, 
        :conditions => ["#{params[:foreign_key] ||= (self.class.to_s.underscore + "_id")} = ?#{params[:conditions] ? " and #{params[:conditions]}" : ""}", self.key])
      end
    end
  end
  
  # Basic parent/child
  def parent
    $db[self.parent_id]["table"].camelize.constantize.new($db[self.parent_id].merge(:pk => self.parent_id)) 
  end
  
  def children
    (q = $db.query).condition("parent_id", :streq, self.key.to_s)
    q.search.zip(q.get).map { |k, v| v["table"].camelize.constantize.new(v.merge(:pk => self.key.to_s))}
  end
  # END GROUP RELATIONS
  
  class << self # Class methods
    # GROUP DATABASE
    def all
      (connected?($db).query { |q| }).map { |r| new(r) }
    end

    def row_count
      connected?($db).size
    end
    
    def first
      new($db[(first = (connected?($db).query { |q| }).first)].merge(:pk => first))
    end

    def last
      new($db[(first = (connected?($db).query { |q| }).last)].merge(:pk => first))
    end

    def query(&block)
      connected?($db).query(&block).map { |i| new(i) }
    end
    # END GROUP DATABSE
    
    # GROUP FIND
    def find_by_key(key)
      ((result = connected?($db)[key]).nil?) ? nil : new(result.merge(:pk => key))
    end

    def find(id, params={})
      case id.class
      # :all, :first, :last etc
      when Symbol
        # Initiate Query
        q = connected?($db).query
        # Set Table
        q.condition("table", :streq, self.name.to_s)

        # Check for query params 
        params.each { |key, value|
          case key
          when :conditions
            if value.is_a? Hash
              value.each { |key, value| q.condition(key, :streq, value) }
            # Array or String
            else
              value = value.to_a # Convert to array in case ?'s need to be substituted 
              subs = value[1..-1] if value.size > 1
              self.sql2tokyo(value[0].gsub("?") { |s| ((val = subs.shift).is_a? String) ? "'#{val}'" : val }).each { |field, op, expr| 
                q.condition(field, op, expr) 
              }
            end
          when :limit
            q.limit(value.to_i)
            limit_one = true if value.to_i == 1
          when :order
            # First part is field name, second part is ASC/DSC but the term changes based on the type e.g. NUMASC or STRDESC
            q.order_by((parts = value.strip.split(" "))[0], ((parts[0] =~ /(_at|_id)/) ? "NUM" : "STR") + parts[1])
          end
        }

        # Handle :first, :last
        (q.limit({:first => 1, :last => -1}[id]); limit_one = true) if [:first, :last].include? id

        # Run Query
        q.search.zip(q.get).map { |k, v| new(v.merge(:pk => k))}.instance_eval((limit_one) ? "first" : "self")
      # Array of IDs
      when Array
        id.map { |k| self.find_by_key(k.to_s) }
      else
        # record key prefix + hash
        self.find_by_key(id.to_s)
      end
    end

    # Takes as input SQL that would appear in the :conditions part of an AR query (after WHERE)
    # Tokyo DB does not take ORs so no need to handle ()'s
    def sql2tokyo(sql_text)
      operators = { "=n" => :numeq, "=s" => :streq, ">" => :numgt, "<" => :numlt, ">=" => :numge, "<=" => :numle, "!=" => :negate,
       "LIKE_INC" => :strinc, "LIKE_BW" => :strbw, "LIKE_EW" => :strew }
      sql_text.strip.chomp.gsub("(", "").gsub(")").split(" and ").map { |field, op, expr|
        operator = case op.upcase
        when "LIKE"
          [[/('|")%[^%'"]*('|")/, "BW"], [/('|")[^%'"]*%('|")/, "EW"], [/('|")%[^%'"]*%('|")/, "INC"]].each { |regex, ext| 
            result = (op.upcase + "_" + ext) if expr =~ regex 
          }
          result ||= "LIKE_INC"
        when "="
          (expr =~ /('|")/) ? "=s" : "=n"
        else
          op.upcase
        end
        [field, operators[operator], expr.gsub(/[%'"]/, "").instance_eval((expr =~ /('|")/) ? "self" : "to_f")]
        # Output format [field, tokyo_operator, value]
      }
    end
    
    def count(id, params={})
      find(id, params).searchcount()
    end
    # END GROUP FIND
    
    # GROUP CREATE
    def create(options = {})
      (object = new(options)).save
      object
    end
    
    def bulk_insert(rows)
      $db.mput(rows)
    end
    
    def bulk_insert_with_check(rows, num, fields)
      duplicates = rows[0, num].inject(false) { |val, row| val || $db.find{ |q|
          fields.each { |f| q.condition(f, ((r[f].is_a? Fixnum) ? :numeq : :streq), r[f]) }
       }.empty? }
      bulk_insert(rows) unless duplicates
    end
    
    def new_key_for_prefix(prefix)
      "#{prefix}#{UUIDTools::UUID.timestamp_create.to_s}"
    end
    # END GROUP UPDATE
    
    protected
    
    # This method ensures that the table is connected to Tyrant
    def connected?(tbl)
      (tbl.nil? or !tbl.is_a?(TokyoTyrant::Table)) ? (raise TyrantError, "Tyrant is not connected") : tbl
    end
  end
end
