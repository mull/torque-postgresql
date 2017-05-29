module Torque
  module PostgreSQL
    module Relation
      module DistinctOn

        attr_accessor :distinct_on_value, :from_only

        # Specifies whether the records should be unique or not by a given set
        # of fields. For example:
        #
        #   User.distinct_on(:name)
        #   # Returns 1 record per distinct name
        #
        #   User.distinct_on(:name, :email)
        #   # Returns 1 record per distinct name and email
        #
        #   User.distinct_on(false)
        #   # You can also remove the uniqueness
        def distinct_on(*value)
          spawn.distinct_on!(*value)
        end

        # Like #distinct_on, but modifies relation in place.
        def distinct_on!(*value)
          self.distinct_on_value = value
          self
        end

        # Specify that the results should come only from the table that the
        # entries were created on. For example:
        #
        #   Activity.only
        #   # Does not return entries for inherited tables
        def only
          spawn.only!
        end

        # Like #only, but modifies relation in place.
        def only!
          self.from_only = true
          self
        end

        private

          # Hook arel build to add the distinct on clause
          def build_arel
            arel = super
            arel.only if self.from_only

            value = self.distinct_on_value
            arel.distinct_on(resolve_column(value)) unless value.nil?
            arel
          end

      end
    end
  end
end
