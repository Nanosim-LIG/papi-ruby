module PAPI

  class Error < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super("#{code}")
    end

    #:stopdoc:
    CLASSES = {}
    #:startdoc:

    private_constant :CLASSES

    def self.error_class(errcode)
      return CLASSES[errcode]
    end

    def self.name(code)
      if CLASSES[code] then
        return CLASSES[code].name
      else
        return "#{code}"
      end
    end

    def name
      return "#{@code}"
    end

    def self.register_error(code, symbol)
      s = <<EOF
      class #{symbol} < Error

        def initialize
          super(#{code})
        end

        def self.name
          return "#{symbol}"
        end

        def name
          return "#{symbol}"
        end

        def self.code
          return #{code}
        end

      end
      CLASSES[#{code}] = #{symbol}
EOF
    end
    errors = []
    errors.push([-1, "EINVAL"],    
                [-2, "ENOMEM"],
                [-3, "ESYS"])
    if VERSION >= Version::new(5,0,0,0) then
      errors.push [-4, "ECMP"]
    else
      errors.push [-4, "ESBSTR"]
    end
    errors.push([-5, "ECLOST"],
                [-6, "EBUG"],
                [-7, "ENOEVNT"],
                [-8, "ECNFLCT"],
                [-9, "ENOTRUN"],
                [-10, "EISRUN"],
                [-11, "ENOEVST"],
                [-12, "ENOTPRESET"],
                [-13, "ENOCNTR"],
                [-14, "EMISC"],
                [-15, "EPERM"],
                [-16, "ENOINIT"])
    if VERSION >= Version::new(4,2,0,0) then
      errors.push([-17, "ENOCMP"],
                  [-18, "ENOSUPP"],
                  [-19, "ENOIMPL"],
                  [-20, "EBUF"],
                  [-21, "EINVAL_DOM"],
                  [-22, "EATTR"],
                  [-23, "ECOUNT"],
                  [-24, "ECOMBO"])
      if VERSION >= Version::new(5,7,0,0) then
        errors.push([-25, "ECMP_DISABLED"])
      end
    elsif VERSION >= Version::new(4,1,0,0) then
      errors.push([-17, "ENOCMP"],
                  [-18, "ENOSUPP"],
                  [-19, "ENOIMPL"],
                  [-20, "EBUF"],
                  [-21, "EINVAL_DOM"])
    elsif VERSION >= Version::new(4,0,0,0) then
      errors.push([-17, "EBUF"],
                  [-18, "EINVAL_DOM"],
                  [-19, "ENOCMP"])
    else
      errors.push([-17, "EBUF"],
                  [-18, "EINVAL_DOM"])
    end
    errors.each  { |code, symbol| eval register_error(code, symbol) }

  end

  def self.error_check(errcode)
      return nil if errcode >= OK
      klass = Error::error_class(errcode)
      if klass then
        raise klass::new
      else
        raise Error::new("#{errcode}")
      end
  end

end
