# DateTime types do not serialize the values for +/-infinity
# correctly for `schema.rb`. This hack gives us a functional
# schema.rb file.
# See also:
#   https://github.com/rails/rails/issues/40751
module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID
        class DateTime < Type::DateTime
          def type_cast_for_schema(value)
            case value
              when ::Float::INFINITY then '::Float::INFINITY'
              when -::Float::INFINITY then '-::Float::INFINITY'
              else super
            end
          end

          # Convert from input to Ruby value
          def serialize(value)
            case value
              when ::Float::INFINITY then "'infinity'::timestamp"
              when -::Float::INFINITY then "'-infinity'::timestamp"
              else super
            end
          end
        end
      end
    end
  end
end
