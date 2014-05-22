#!python2

# --------------------------------------------------------------------------------------------------
# Hand-made by kin @ agava at Fri 04 Apr 2014
# -------------------------------------------------------------------------------------------------- 
# This module is a way for me to organize my Nagios configurations.
# -------------------------------------------------------------------------------------------------- 

class CfgBase (): 
    separator = { "tabulator": (" "*4)
            , "equator": " "
            , "joiner": ", "
            , "linebreaker": ";"
            , "commenter": "# "
            , "headliner": ("# " + "-"*78 + "\n") }

class CfgDirective (CfgBase):
    def __init__ ( self, name, comment, *values ):
        self.name = str (name)
        self.values = []
        if comment: self.comment = str (comment)
        else: self.comment = None
        if len ( values ) == 0: self.values = [0] # Set initial value.
        else: self.values = values

    def __str__ (self):
        return ( self.separator["tabulator"] + self.name
                + self.separator["equator"] # Directive name.
                + ( self.separator["joiner"].join ( map ( str, self.values ) )
                    + self.separator["linebreaker"] ) # Directive value.
                + ( " " + self.separator["commenter"]
                    + self.comment if self.comment else "" ) ) # Directive comment.

    def addValue ( self, value ):
        self.values.append ( value ) 

class CfgObject (CfgBase):
    def __init__ ( self, name, comment, *directives ):
        self.name = name
        if comment: self.comment = comment
        else: self.comment = None
        self.directives = directives

    def addDirective ( self, directive ):
        self.directives.append ( directive )

    def __str__ (self):
        return ( ( ("".join ( map ( (lambda s: self.separator["commenter"] + s)
            , str (self.comment) . splitlines(True) ) ) + "\n") if self.comment else "")
            +  "define " + str ( self.name ) + " {\n" # Object header.
            + "\n".join ( map ( str, self.directives ) ) # Object body.
            + "\n}\n" ) # A closing brace.

class CfgModule (CfgBase):
    def __init__ ( self, name, comment, *objects ):
        self.name = name
        if comment: self.comment = comment
        else: self.comment = None
        self.objects = objects 

    def __str__ (self):
        return ( self.separator["headliner"] + self.separator["commenter"]
                + "Module "+ str (self.name) + "\n" + self.separator["headliner"]
                + "".join ( map (
                      (lambda s: "# " + s)
                    , str (self.comment) . splitlines(True) ) )
                + "\n" + self.separator["headliner"] + "\n" 
                + "\n".join ( map ( str, self.objects ) ) )

    def addObject ( self, obj ):
        self.objects.append ( obj )

