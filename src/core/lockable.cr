module Syn::Core
  module Lockable
    abstract def lock : Nil
    abstract def unlock : Nil
  end
end
