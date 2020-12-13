# Hacks to fix ActiveRecord bugs.
module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID
        class DateTime < Type::DateTime
          # DateTime types do not serialize the values for +/-infinity
          # correctly for `schema.rb`. This hack gives us a functional
          # schema.rb file.
          # See also:
          #   https://github.com/rails/rails/issues/40751
          def type_cast_for_schema(value)
            case value
              when ::Float::INFINITY then '::Float::INFINITY'
              when -::Float::INFINITY then '-::Float::INFINITY'
              else super
            end
          end
        end
      end
    end
  end

  module AttributeMethods
    module TimeZoneConversion
      class TimeZoneConverter
        # This fixes an issue where ActiveRecord screws up and incorrectly
        # dirties a model with +/-Float::INFINITY when trying to mediate
        # between an in-memory copy of the data and fresh info from the
        # database. There are a variety of situations where this happens,
        # but one simple one is calling `collection.to_a`, e.g:
        #
        #     # page.urls is a :has_many collection of records where
        #     # :from_time defaults to -infinity.
        #     some_url = page.urls.create(url: 'https://example.gov/')
        #     some_url.from_time
        #     => -Infinity  # GOOD
        #     page.urls.to_a
        #     some_url.from_time
        #     => nil   # WTF
        #     some_url.changed?
        #     => true  # WTF
        #
        # What is happening here, you ask? WELL. `page.urls.to_a` is one of a
        # variety of things that might cause ActiveRecord to go fetch some
        # info from the database (in this case, I think because it can't be
        # sure its in-memory version of page.urls has all the data). It also
        # knows it has some cached in-memory data in the collection, too
        # (that's `some_url` in the example above). So it tries to merge the
        # data from the DB into any matching in-memory records (very cool!).
        #   See: `ActiveRecord::Associations::CollectionAssociation#merge_target_lists`
        #   https://github.com/rails/rails/blob/v6.0.3.4/activerecord/lib/active_record/associations/collection_association.rb#L305-L333)
        #
        # Ultimately, the values have to go through `Type#cast` in
        # ActiveRecord/ActiveModel before they can be compared.
        #   See: `ActiveModel::Attribute::FromUser`
        #   https://github.com/rails/rails/blob/v6.0.3.4/activemodel/lib/active_model/attribute.rb#L173-L181
        #
        # The rest of the ActiveRecord/Postgres machinery happily deserializes
        # `'-infinity'` from the database to `-Float::INFINITY`, and so we are
        # at this point calling `DateTime.cast(-Float::INFINITY)`. That method
        # is overridden by:
        #   `ActiveRecord::AttributeMethods::TimeZoneConversion::TimeZoneConverter#cast`
        # here, which pessimistically returns `nil` if you hand it anything
        # other than a Hash or something that responds to :in_time_zone (e.g.
        # a Time or a String). We override it here to handle Float::INFINITY.
        #
        # NOTE: this is really just another effect of this issue:
        #   https://github.com/rails/rails/issues/40595
        # which covers the inability to set `Float::INFINITY` as a value.
        # The same logic that is breaking there is the cause of this issue.
        #
        # It's worth noting that normal Time casting logic in
        #   ActiveRecord::ConnectionAdapters::PostgreSQL::OID::DateTime#cast_value
        # will return values it it doesn't know how to handle (like
        # `Float::INFINITY`) unchanged, while the decorated version you get
        # with `TimeZoneConversion` does the opposite -- if it gets something
        # it doesn't recognize, it will convert the value to `nil`.
        #
        # This problematic behavior is turned on by setting:
        #   config.active_record.time_zone_aware_attributes = true
        # which we don't explicitly do, but it gets turned on anyway. I'm a
        # little leery of causing some new bugs by modifying that setting
        # right now, so this hack feels like a better solution (it's still a
        # bug that the setting breaks things) than the easy workaround of
        # changing that setting to false, at least for now.
        alias :_cast :cast
        def cast(value)
          case value
            when ::Float::INFINITY then ::Float::INFINITY
            when -::Float::INFINITY then -::Float::INFINITY
            else _cast(value)
          end
        end
      end
    end
  end
end
