unit uBignumArithmetic;

interface

const
  DECIMAL_SEPARATOR = '.';
  MAX_SIZE = 255; // не более максимального значения TDigit
  DIGITS_IN_ONE_CELL = 2; // зависит от TDigit: MAX_NUM_IN_ONE_CELL должен входить в диапазон значений TDigit  
  BASE = 10; // фиксированная величина: не изменять
  MAX_NUM_IN_ONE_CELL = trunc( power(BASE, DIGITS_IN_ONE_CELL) ) - 1;

type
  TDigit = byte;
  TDigitArr = array[0..MAX_SIZE] of TDigit;
  
  TLongReal = record // многоразрядное действительное число
    intPart: TDigitArr; // целая часть
    fracPart: TDigitArr; // дробная часть
    
    /// Прежде чем начать работать с переменными типа TLongReal, необходимо выполнить этот метод.
    procedure init();
    
    class function operator <(a, b: TLongReal): boolean;
    class function operator =(a, b: TLongReal): boolean;
  end;

/// Считывает строку из файла fi. Если строка является многоразрядным числом, то
/// число записывается в переменную a, в err записывается false.
/// Иначе, в переменную err записывается значение true, значение a неопределено.
procedure readTLongReal(fi: text; var a: TLongReal; var err: boolean);

/// Записывает многоразрядное число a в файл fo без перевода строки.
procedure writeTLongReal(fo: text; a: TLongReal);

/// Возвращает сумму многоразрядных чисел a и b в виде многоразрядного числа.
/// В случае переполнения суммы значение самого старшего разряда отбрасывается.
function addTLongReal(a, b: TLongReal): TLongReal;

/// Возвращает модуль разности многоразрядных чисел a и b в виде многоразрядного числа.
function absSubTLongReal(a, b: TLongReal): TLongReal;

implementation

const
  SIZE = 0;

type
  DynStrArr = array of string;

procedure TLongReal.init();
begin
  intPart[SIZE] := 1;
  intPart[1] := 0;
  fracPart[SIZE] := 1;
  fracPart[1] := 0
end;

class function TLongReal.operator <(a, b: TLongReal): boolean;
var
  i: integer;
begin
  result := false;

  if (a.intPart[SIZE] > b.intPart[SIZE]) or (a = b) then
    result := false
  else if a.intPart[SIZE] < b.intPart[SIZE] then
    result := true
  else begin
  
    for i := a.intPart[SIZE] downto 1 do begin
      if a.intPart[i] < b.intPart[i] then begin
        result := true;
        exit;
      end else if a.intPart[i] > b.intPart[i] then begin
        result := false;
        exit;
      end;
    end;
    
    for i := 1 to min(a.fracPart[SIZE], b.fracPart[SIZE]) do begin
      if a.fracPart[i] < b.fracPart[i] then begin
        result := true;
        exit;
      end else if a.fracPart[i] > b.fracPart[i] then begin
        result := false;
        exit;
      end;
    end;
    
  end;
end;

class function TLongReal.operator =(a, b: TLongReal): boolean;
var
  i: integer;
begin
  result := true;
  
  if (a.intPart[SIZE] = b.intPart[SIZE]) and (a.fracPart[SIZE] = b.fracPart[SIZE]) then begin
      
    i := 1;
    while (i <= a.intPart[SIZE]) and result do
      if a.intPart[i] <> b.intPart[i] then
        result := false
      else
        i += 1;
    
    if result then begin
      i := 1;
      while (i <= a.fracPart[SIZE]) and result do
        if a.fracPart[i] <> b.fracPart[i] then
          result := false
        else
          i += 1;
    end;
        
  end else
    result := false;
end;

function isValidRealNum(s: string): boolean;
var
  i, j: integer;
begin
  result := true;
  
  for i := 1 to length(s) do
    if not (s[i] in ['0'..'9', DECIMAL_SEPARATOR]) then begin
      result := false;
      exit;
    end;
  
  i := pos(DECIMAL_SEPARATOR, s);
  
  if (i <> 0) and ( (i+1) <= length(s) ) then begin
    j := pos(DECIMAL_SEPARATOR, s, i+1);
    if j > i then
      result := false;
  end;
end;

function split(s, delim: string): DynStrArr;
var
  prevDelimPos, currDelimPos: integer;
begin
  prevDelimPos := 1 - length(delim);
  currDelimPos := pos(delim, s, prevDelimPos + length(delim));
  
  setlength(result, 0);
  
  while currDelimPos <> 0 do begin
    setlength(result, length(result) + 1);
    result[high(result)] := copy(s, prevDelimPos + length(delim), 
      currDelimPos - prevDelimPos - length(delim));
    
    prevDelimPos := currDelimPos;
    currDelimPos := pos(delim, s, prevDelimPos + length(delim));
  end;
  
  setlength(result, length(result) + 1);
  result[high(result)] := copy(s, prevDelimPos + length(delim),
    length(s) - prevDelimPos);
end;

procedure readTLongReal(fi: text; var a: TLongReal; var err: boolean);
const
  INT = 0;
  FRAC = 1;
var
  s: string;
  parts: DynStrArr;
  i, idx: integer;
begin
  readln(fi, s);
  s := trim(s);
 
  if (length(s) > 0) and isValidRealNum(s) then begin
    parts := split(s, DECIMAL_SEPARATOR);
    
    if length(parts[INT]) > 0 then begin
    
      if length(parts[INT]) > (MAX_SIZE * DIGITS_IN_ONE_CELL) then begin
        err := true;
        exit;
      end;
      
      // обрезаем незначащие нули в целой части
      i := 1;
     while (i < length(parts[INT])) and (parts[INT][i] = '0') do
        i += 1;
      parts[INT] := copy(parts[INT], i, length(parts[INT])-i+1);
      
      // заполняем массив целой части
      a.intPart[SIZE] := ceil(length(parts[INT]) / DIGITS_IN_ONE_CELL);
      idx := length(parts[INT]) + 1;
      for i := 1 to a.intPart[SIZE] do begin
        idx -= DIGITS_IN_ONE_CELL;
        if idx > 0 then
          a.intPart[i] := strToInt( copy(parts[INT], idx, DIGITS_IN_ONE_CELL) )
        else
          a.intPart[i] := strToInt( copy(parts[INT], 1, DIGITS_IN_ONE_CELL - abs(idx) - 1) );
      end;
    end;
    
    // если есть дробная часть
    if (length(parts) = 2) and (length(parts[FRAC]) > 0) then begin
    
      if length(parts[FRAC]) > (MAX_SIZE * DIGITS_IN_ONE_CELL) then begin
        err := true;
        exit;
      end;
      
      // обрезаем незначащие нули дробной части
      i := length(parts[FRAC]);
      while (i > 1) and (parts[FRAC][i] = '0') do
        i -= 1;
      parts[FRAC] := copy(parts[FRAC], 1, i);
      
      // "выравнивание" нулями последней ячейки дробной части
      if (length(parts[FRAC]) mod DIGITS_IN_ONE_CELL) <> 0 then
        parts[FRAC] += '0'*(DIGITS_IN_ONE_CELL - (length(parts[FRAC]) mod DIGITS_IN_ONE_CELL));
      
      // заполняем массив дробной части
      a.fracPart[SIZE] := ceil(length(parts[FRAC]) / DIGITS_IN_ONE_CELL);
      idx := 1;
      for i := 1 to a.fracPart[SIZE] do begin
        a.fracPart[i] := strToInt( copy(parts[FRAC], idx, DIGITS_IN_ONE_CELL) );
        idx += DIGITS_IN_ONE_CELL;
      end;
    end;
  
  end else
    err := true;  
end;

function digitsInNum(a: integer): integer;
begin
  result := 0;
  
  if a = 0 then
    result := 1
  else begin
    while a <> 0 do begin
      a := a div 10;
      result += 1;
    end;
  end;
end;

procedure writeTLongReal(fo: text; a: TLongReal);
var
  i: integer;
  lastFracPartDigit: TDigit;
  divided: boolean;
begin
  // выводим целую часть
  write(fo, a.intPart[ a.intPart[SIZE] ]);
  for i := a.intPart[SIZE] - 1 downto 1 do
    write(fo, '0'*(DIGITS_IN_ONE_CELL - digitsInNum(a.intPart[i])), a.intPart[i]);
  
  // выводим дробную часть
  write(fo, DECIMAL_SEPARATOR);
  for i := 1 to a.fracPart[SIZE] - 1 do
    write(fo, '0'*(DIGITS_IN_ONE_CELL - digitsInNum(a.fracPart[i])), a.fracPart[i]);
     
  // опускаем незначащие нули последнего разряда дробной части
  lastFracPartDigit := a.fracPart[ a.fracPart[SIZE] ];
  
  divided := false;
  while (lastFracPartDigit <> 0) and ((lastFracPartDigit mod BASE) = 0) do begin
    lastFracPartDigit := lastFracPartDigit div BASE;
    divided := true;
  end;

  if (lastFracPartDigit = 0) or divided then
    write(fo, lastFracPartDigit)
  else
    write(fo, '0'*(DIGITS_IN_ONE_CELL - digitsInNum(lastFracPartDigit)), lastFracPartDigit);
end;

function addTLongReal(a, b: TLongReal): TLongReal;
var
  i: integer;
  curr, carry: TDigit;
begin
  // сумма дробных частей
  result.fracPart[SIZE] := max(a.fracPart[SIZE], b.fracPart[SIZE]);
  
  carry := 0;
  for i := result.fracPart[SIZE] downto 1 do begin
    curr := a.fracPart[i] + b.fracPart[i] + carry;
    carry := 0;
    
    if curr > MAX_NUM_IN_ONE_CELL then begin
      result.fracPart[i] := curr mod (MAX_NUM_IN_ONE_CELL + 1);
      carry := (curr - result.fracPart[i]) div (MAX_NUM_IN_ONE_CELL + 1);
    end else          
      result.fracPart[i] := curr;
  end;
  
  // удаление нулевых ячеек из дробной части
  i := result.fracPart[SIZE];
  while (result.fracPart[i] = 0) and (i >= 1) do begin
    result.fracPart[SIZE] -= 1;
    i -= 1;
  end;

  // сумма целых частей
  result.intPart[SIZE] := max(a.intPart[SIZE], b.intPart[SIZE]);

  for i := 1 to result.intPart[SIZE] do begin
    curr := a.intPart[i] + b.intPart[i] + carry;
    carry := 0;
              
    if curr > MAX_NUM_IN_ONE_CELL then begin
      result.intPart[i] := curr mod (MAX_NUM_IN_ONE_CELL + 1);
      carry := (curr - result.intPart[i]) div (MAX_NUM_IN_ONE_CELL + 1);
    end else          
      result.intPart[i] := curr;
  end;
  
  if carry <> 0 then begin
    if result.intPart[SIZE] <> MAX_SIZE then begin
      result.intPart[SIZE] += 1;
      result.intPart[ result.intPart[SIZE] ] := carry;
    end else begin // если переполнение
      // удаляем незначащие нули целой части
      i := a.intPart[SIZE];
      while (i > 1) and (result.intPart[i] = 0) do begin
        result.intPart[SIZE] -= 1;
        i -= 1;
      end; 
    end;
  end;
end;

function absSubTLongReal(a, b: TLongReal): TLongReal;
var
  i, j: integer;
begin
  if a = b then begin
    result.init();
  end else begin
    
    if a < b then
      swap(a, b); // b - a
      
    result.intPart[SIZE] := a.intPart[SIZE];
    result.fracPart[SIZE] := max(a.fracPart[SIZE], b.fracPart[SIZE]);
    
    // разность дробных частей
    for i := max(a.fracPart[SIZE], b.fracPart[SIZE]) downto 1 do begin
      if a.fracPart[i] < b.fracPart[i] then begin
      
        j := i - 1;
        while (j >= 1) and (a.fracPart[j] = 0) do begin
          a.fracPart[j] := MAX_NUM_IN_ONE_CELL;
          j -= 1;
        end;
        
        if j < 1 then begin
          j := 1;
          while (j <= a.intPart[SIZE]) and (a.intPart[j] = 0) do begin
            a.intPart[j] := MAX_NUM_IN_ONE_CELL;
            j += 1;
          end;
          a.intPart[j] -= 1;
        end else
          a.fracPart[j] -= 1;
        
        result.fracPart[i] := a.fracPart[i] + MAX_NUM_IN_ONE_CELL + 1 - b.fracPart[i];
        
      end else
        result.fracPart[i] := a.fracPart[i] - b.fracPart[i];
    end;
    
    // разность целых частей
    for i := 1 to a.intPart[SIZE] do begin
      if a.intPart[i] < b.intPart[i] then begin
      
        j := i + 1;
        while (j <= a.intPart[SIZE]) and (a.intPart[j] = 0) do begin
          a.intPart[j] := MAX_NUM_IN_ONE_CELL;
          j += 1;
        end;
        a.intPart[j] -= 1;
        
        result.intPart[i] := a.intPart[i] + MAX_NUM_IN_ONE_CELL + 1 - b.intPart[i];
      
      end else
        result.intPart[i] := a.intPart[i] - b.intPart[i];
    end;
    
    // удаление незначащих нулей из целой части
    i := result.intPart[SIZE];
    while (i > 1) and (result.intPart[i] = 0) do begin
      result.intPart[SIZE] -= 1;
      i -= 1;
    end;
    
    // удаление незначащих нулей из дробной части
    i := result.fracPart[SIZE];
    while (i > 1) and (result.fracPart[i] = 0) do begin
      result.fracPart[SIZE] -= 1;
      i -= 1;
    end;
    
  end;
end;

end.