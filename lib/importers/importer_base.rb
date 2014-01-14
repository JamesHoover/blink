class ImporterBase
  def import(array)
  end
  def add(item)
  end
  def call(method)
    eval "@bsi.#{method.to_s}"
  end
end
