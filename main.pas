uses
  uBignumArithmetic;

var
  fi, fo: text;
  a, b: TLongReal;
  errA, errB: boolean;

begin
  assign(fi, 'input.txt');
  reset(fi);
  assign(fo, 'output.txt');
  rewrite(fo);
  
  a.init();
  b.init();

  readTLongReal(fi, a, errA);
  readTLongReal(fi, b, errB);
  
  if not errA and not errB then begin
  
    write(fo, 'a + b: ');
    writeTLongReal(fo, addTLongReal(a, b));
    writeln(fo);
    
    if a = b then
      writeln(fo, 'Numbers are equal.')
    else begin
      write(fo, 'a - b: ');
      writeTLongReal(fo, absSubTLongReal(a, b));
    end;
    
  end else
    writeln(fo, 'Input error.');
  
  close(fi);
  close(fo);
end.