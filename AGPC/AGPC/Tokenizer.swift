//
//  File.swift
//  AGPC
//
//  Created by Andrey Gurev on 06.10.17.
//  Copyright © 2017 Andrey Gurev. All rights reserved.
//  
import Foundation

public var errorMessages = [String]()

extension String {
    var length: Int {
        return self.characters.count
    }
    
    subscript (i: Int) -> String {
        return self[i..<i + 1]
    }
    
    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }
    
    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }
    
    var asciiArray: [UInt32] {
        return unicodeScalars.filter{$0.isASCII}.map{$0.value}
    }
    
    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}

extension Character {
    var asciiValue: Int {
        let value = String(self).unicodeScalars.filter{$0.isASCII}.first?.value
        return Int(value!)
    }
}

class Tokenizer {
    private var index = 0
    
    struct Token {
        var position:(row: Int, col: Int)
        var type: TokenType
        var text: String
        var value: String
        init(_ text: String,_ type: TokenType,_ position:(Int, Int),_ value:String = "") {
            self.type = type
            self.text = text
            self.value = (value.isEmpty) ? self.text : value
            self.position = position
        }
    }
    
    init(text: String) {
        self.text = text
        self.text.append(" \0")
        initTable()
        analyze()
    }
    
    private enum State: String {
        case BEGIN, INTEGER, EXP_NUMBER, DOUBLE_NUMBER, DOUBLE_NUMBER_DOT,
        WORD, SLASH, SPECIAL, BINARY_INT, HEX_INT, OCTAL_INT,
        SPECIAL_MAX, SPECIAL_DERELICT, DOUBLE_DOT, DOT, STRING,
        COMMENT, COMMENT_LONG, SHIFT, END, ENDOFFILE
        
        static var count: Int { return State.END.hashValue + 1}
    }
    
    private var text: String
    private var currentState: State = .BEGIN
    private var newState: State = .BEGIN
    var lexems = [Token]()
    
    private var stateTable = Array(repeating: Array<State>(repeating: .END, count: 128), count: State.count)

    func nextToken() { self.index+=1 }
    
    func currentToken() -> Token {
        return lexems[self.index]
    }
    
    // MARK: Init state table
    
    private func initTable() {
        stateTable[State.BEGIN.hashValue][Character("$").asciiValue] = .HEX_INT
        stateTable[State.BEGIN.hashValue][Character("&").asciiValue] = .OCTAL_INT
        stateTable[State.BEGIN.hashValue][Character("%").asciiValue] = .BINARY_INT
        stateTable[State.BINARY_INT.hashValue][Character("0").asciiValue] = .BINARY_INT
        stateTable[State.BINARY_INT.hashValue][Character("1").asciiValue] = .BINARY_INT
        
        for i in Character("a").asciiValue...Character("z").asciiValue {
            if(i <= Character("f").asciiValue) {
                stateTable[State.HEX_INT.hashValue][i] = .HEX_INT
            }
            stateTable[State.BEGIN.hashValue][i] = .WORD
            stateTable[State.WORD.hashValue][i] = .WORD
        }
        
        for i in Character("A").asciiValue...Character("Z").asciiValue {
            if(i <= Character("F").asciiValue) {
                stateTable[State.HEX_INT.hashValue][i] = .HEX_INT
            }
            stateTable[State.BEGIN.hashValue][i] = .WORD
            stateTable[State.WORD.hashValue][i] = .WORD
        }
        
        stateTable[State.WORD.hashValue][Character("_").asciiValue] = .WORD
        stateTable[State.BEGIN.hashValue][Character("_").asciiValue] = .WORD
        
        for i in Character("0").asciiValue...Character("9").asciiValue {
            if(i < Character("8").asciiValue) {
                stateTable[State.OCTAL_INT.hashValue][i] = .OCTAL_INT
            }
            stateTable[State.BEGIN.hashValue][i] = .INTEGER
            stateTable[State.INTEGER.hashValue][i] = .INTEGER
            stateTable[State.WORD.hashValue][i] = .WORD
            
            stateTable[State.DOUBLE_NUMBER.hashValue][i] = .DOUBLE_NUMBER
            stateTable[State.DOUBLE_NUMBER_DOT.hashValue][i] = .DOUBLE_NUMBER
            stateTable[State.EXP_NUMBER.hashValue][i] = .EXP_NUMBER
            stateTable[State.HEX_INT.hashValue][i] = .HEX_INT
        }
    
        stateTable[State.INTEGER.hashValue][Character(".").asciiValue] = .DOUBLE_NUMBER_DOT
        stateTable[State.DOUBLE_NUMBER.hashValue][Character("E").asciiValue] = .EXP_NUMBER
        stateTable[State.DOUBLE_NUMBER.hashValue][Character("e").asciiValue] = .EXP_NUMBER
        stateTable[State.DOUBLE_NUMBER_DOT.hashValue][Character(".").asciiValue] = .END
        
        stateTable[State.BEGIN.hashValue][Character(" ").asciiValue] = .SHIFT
        stateTable[State.BEGIN.hashValue][Character("\n").asciiValue] = .SHIFT
        stateTable[State.BEGIN.hashValue][Character("\t").asciiValue] = .SHIFT
        stateTable[State.SHIFT.hashValue][Character(" ").asciiValue] = .SHIFT
        stateTable[State.SHIFT.hashValue][Character("\n").asciiValue] = .SHIFT
        stateTable[State.SHIFT.hashValue][Character("\t").asciiValue] = .SHIFT
        
        stateTable[State.BEGIN.hashValue][Character("+").asciiValue] = .SPECIAL
        stateTable[State.BEGIN.hashValue][Character("-").asciiValue] = .SPECIAL
        stateTable[State.BEGIN.hashValue][Character("*").asciiValue] = .SPECIAL
        stateTable[State.BEGIN.hashValue][Character(">").asciiValue] = .SPECIAL
        stateTable[State.BEGIN.hashValue][Character(":").asciiValue] = .SPECIAL
        stateTable[State.BEGIN.hashValue][Character("<").asciiValue] = .SPECIAL_DERELICT
        stateTable[State.BEGIN.hashValue][Character("@").asciiValue] = .SPECIAL_MAX
        stateTable[State.BEGIN.hashValue][Character("[").asciiValue] = .SPECIAL_MAX
        stateTable[State.BEGIN.hashValue][Character("]").asciiValue] = .SPECIAL_MAX
        stateTable[State.BEGIN.hashValue][Character(";").asciiValue] = .SPECIAL_MAX
        stateTable[State.BEGIN.hashValue][Character(",").asciiValue] = .SPECIAL_MAX
        stateTable[State.BEGIN.hashValue][Character("(").asciiValue] = .SPECIAL_MAX
        stateTable[State.BEGIN.hashValue][Character(")").asciiValue] = .SPECIAL_MAX
        stateTable[State.BEGIN.hashValue][Character("=").asciiValue] = .SPECIAL_MAX
        stateTable[State.BEGIN.hashValue][Character("^").asciiValue] = .SPECIAL_MAX
        
        stateTable[State.SPECIAL.hashValue][Character("=").asciiValue] = .SPECIAL_MAX
        stateTable[State.SPECIAL_DERELICT.hashValue][Character(">").asciiValue] = .SPECIAL_MAX
        stateTable[State.SPECIAL_DERELICT.hashValue][Character("=").asciiValue] = .SPECIAL_MAX
        
        stateTable[State.BEGIN.hashValue][Character("/").asciiValue] = .SLASH
        stateTable[State.SLASH.hashValue][Character("/").asciiValue] = .COMMENT
        stateTable[State.SLASH.hashValue][Character("=").asciiValue] = .SPECIAL_MAX
        
        stateTable[State.BEGIN.hashValue][Character("{").asciiValue] = .COMMENT_LONG
        stateTable[State.BEGIN.hashValue][Character("'").asciiValue] = .STRING
        
        stateTable[State.BEGIN.hashValue][Character("\0").asciiValue] = .ENDOFFILE
        
        for i in 0..<128 {
            stateTable[State.STRING.hashValue][i] = .STRING
            stateTable[State.COMMENT.hashValue][i] = .COMMENT
            stateTable[State.COMMENT_LONG.hashValue][i] = .COMMENT_LONG
        }
        
        stateTable[State.STRING.hashValue][Character("'").asciiValue] = .END
        stateTable[State.COMMENT.hashValue][Character("\n").asciiValue] = .END
        stateTable[State.COMMENT_LONG.hashValue][Character("}").asciiValue] = .END
        
        stateTable[State.BEGIN.hashValue][Character(".").asciiValue] = .DOT
        stateTable[State.DOT.hashValue][Character(".").asciiValue] = .DOUBLE_DOT

    }
    
    func lexemTable(_ lexems: [Token]) ->  String {
        let column1PadLength = 20
        let columnDefaultPadLength = 20
        
        var errors = ""
        for error in errorMessages {
            errors += error + "\n"
        }
        
        let headerString = "Position".padding(toLength: column1PadLength, withPad: " ", startingAt: 0) + "Type".padding(toLength: column1PadLength + 5, withPad: " ", startingAt: 0) +
            "Text".padding(toLength: columnDefaultPadLength, withPad: " ", startingAt: 0) +
            "Value".padding(toLength: columnDefaultPadLength, withPad: " ", startingAt: 0)
        
        let lineString = "".padding(toLength: headerString.characters.count, withPad: "-", startingAt: 0)
        
        var dataString = ""
        for lexem in lexems {
            let number = "(\(lexem.position.row),\(lexem.position.col))"
            dataString += number.padding(toLength: column1PadLength, withPad: " ", startingAt: 0) + lexem.type.rawValue.padding(toLength: columnDefaultPadLength + 5, withPad: " ", startingAt: 0) + lexem.text.padding(toLength: columnDefaultPadLength, withPad: " ", startingAt: 0) +
                lexem.value.padding(toLength: columnDefaultPadLength, withPad: " ", startingAt: 0)
            dataString.append("\n")
        }
        return "\(errors)\(headerString)\n\(lineString)\n\(dataString)"
    }
    
    private func analyze(){
        var i = 0
        var symbolPosition = (row: 1, col: 1)
        var currentCol = 1
        var lexemText = ""
        
        while(i != text.characters.count) {
            let symbol = Character(text[i])
            currentState = newState
            newState = stateTable[currentState.hashValue][symbol.asciiValue]
            
            switch(newState) {
            case .END:
                switch(currentState) {
                case .WORD:
                    let lexem = getKeyWordType(lexemText)
                    lexem == nil ? lexems.append(Token(lexemText, .ID, symbolPosition)) :
                        lexems.append(Token(lexemText, lexem!, symbolPosition))
                case .SHIFT:
                    newState = .BEGIN
                case .DOUBLE_NUMBER_DOT:
                    i-=1
                    currentCol-=1
                    lexemText = lexemText[0..<lexemText.count - 1]
                    lexems.append(Token(lexemText, .INT, symbolPosition))
                case .DOT:
                    lexems.append(Token(lexemText, .DOT, symbolPosition))
                case .DOUBLE_DOT:
                    lexems.append(Token(lexemText, .D_DOT, symbolPosition))
                case .INTEGER:
                    lexems.append(Token(lexemText, .INT, symbolPosition))
                case .DOUBLE_NUMBER:
                    lexems.append(Token(lexemText, .DOUBLE, symbolPosition))
                case .EXP_NUMBER:
                    lexems.append(Token(lexemText, .DOUBLE, symbolPosition, String(Double(lexemText)!)))
                case .HEX_INT:
                    lexems.append(Token(lexemText, .INT, symbolPosition, String(Int(strtoul(lexemText.replacingOccurrences(of: "$", with: ""), nil, 16)))))
                case .BINARY_INT:
                    lexems.append(Token(lexemText, .INT, symbolPosition, String(Int(strtoul(lexemText.replacingOccurrences(of: "%", with: ""), nil, 2)))))
                case .OCTAL_INT:
                    lexems.append(Token(lexemText, .INT, symbolPosition, String(Int(strtoul(lexemText.replacingOccurrences(of: "&", with: ""), nil, 8)))))
                case .SPECIAL_MAX, .SPECIAL, .SLASH, .SPECIAL_DERELICT:
                    lexems.append(Token(lexemText, getType(lexemText), symbolPosition))
                case .STRING:
                    lexemText.append(symbol)
                    i+=1
                    lexems.append(Token(lexemText, .STRING, symbolPosition, lexemText.replacingOccurrences(of: "'", with: "")))
                case .COMMENT_LONG:
                    lexemText.append(symbol)
                    i+=1
                    lexems.append(Token(lexemText, .LONG_COMMENT, symbolPosition))
                case .COMMENT:
                    lexems.append(Token(lexemText, .COMMENT, symbolPosition))
                default:
                    errorMessages.append("Unknown symbol - \"\(symbol)\" in \(symbolPosition.row, currentCol) position")
                    lexemText = ""
                    i+=1
                    currentCol+=1
                    newState = .BEGIN
                }
                lexemText = ""
                i-=1
                currentCol-=1
                newState = .BEGIN
            case .SHIFT:
                if(symbol == "\n"){
                    symbolPosition.row+=1
                    currentCol = 1
                }
                newState = .BEGIN
            case .ENDOFFILE:
                lexems.append(Token("EndOfFile", .ENDOFFILE, symbolPosition))
            default:
                if (lexemText.isEmpty){
                    symbolPosition = (symbolPosition.row, currentCol)
                }
                lexemText.append(symbol)
            }
            i+=1
            currentCol+=1
        }
    }
}
