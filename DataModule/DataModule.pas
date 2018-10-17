unit DataModule;

interface

uses
  SysUtils, Classes, DB, IniFiles, Windows, Controls, Forms, Dialogs,
  IBX.IBCustomDataSet, IBX.IBQuery, IBX.IBDatabase, FireDAC.Stan.Intf,
  FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.Phys.FB, FireDAC.Phys.FBDef, FireDAC.VCLUI.Wait, FireDAC.Stan.Param,
  FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client, IBX.IBScript
  , System.Net.HTTPClient, System.StrUtils, ShellApi
  ;

type

  TDM = class(TDataModule)
    BaseDatos: TIBDatabase;
    Transaccion: TIBTransaction;
    ConfigQuery: TIBQuery;
    Query: TIBQuery;
    Consulta: TIBScript;
    FDConnection1: TFDConnection;
    procedure DataModuleCreate(Sender: TObject);
    function ObtenerConfig(campo:string):Variant;
    procedure LeerINI;
    procedure EscribirINI;
  private
    { Private declarations }
  public
  const
    NumThreads: Integer = 4;
  public
    { Public declarations }
    Unidad: string;
    // Gratis:boolean;
    IniFile: TIniFile;
    procedure connection;
    procedure chequeo;
    procedure TraerUsuario;
    procedure DejarUsuario;
    function ExecuteProcess(ProcessName, Path: String): Cardinal;
    procedure VaciarBase;
    function Descargar(FURL,FFileName:string):string;
    function TextoAfecha(StrDate : string):TDateTime;
    function ReadTextFile(FileName : String):string;
    { function Gratis(arch: String): boolean; }
  end;

const
  v: array [0 .. 22] of string = ('MenuExpress', 'MenuStock', 'Articulos',
    'VaciarBase', 'Vender', 'Comprar', 'AnularVenta', 'RetiroCaja', 'Rubro',
    'Categoria', 'SubCategoria', 'Stock', 'CajaL', 'GananciaXvta', 'PreciosL',
    'ClientesL', 'CompraL', 'VentaL', 'Empresa', 'Configuracion', 'Backup',
    'Migrar', 'Licencia');

type
  TCompartido = record
    Numero: Integer;
    Cadena: String[20];
  end;

  PCompartido = ^TCompartido;

var
  DM: TDM;
  Compartido: PCompartido;
  FicheroM: THandle;
  Usuario, Licencia, U, Path, Oculto, Control, Maquina, Fecha, Empresa, CUIT, IngresosBrutos, reporte: string;
  Permiso: Integer;
  LoginOK, Cancelar: boolean;
  detalle, memo, BasedeDatos, mode: string; // revisar
  webUrl, webRes, webUsr, webPsw, webUpd : string;
  afipUrl, afipRes, afipUsr, afipPsw : string;

implementation

{$R *.dfm}
{ function TDM.Gratis;
  var
  i: Integer;
  a: string;
  begin
  for i := 0 to High(v) do
  begin
  a := v[i] + '.exe';
  if arch = a then
  begin
  Result := True;
  Exit;
  end;
  end;
  Result := False; // ?
  end; }

function TDM.ExecuteProcess;
var
  StartInfo: TStartupInfo;
  ProcInfo: TProcessInformation;

begin
  Result := 0;

  FillChar(StartInfo, SizeOf(StartInfo), 0);
  StartInfo.cb := SizeOf(StartInfo);

  if CreateProcess(PChar(ProcessName), nil, nil, nil, False, 0, nil,
    PChar(Path), StartInfo, ProcInfo) then
    Result := ProcInfo.hProcess;
end;

function GetVolumeID(DriveChar: string): String;
var
  MaxFileNameLength, VolFlags, SerNum: DWord;
begin
  if GetVolumeInformation(PChar(DriveChar + '\'), nil, 0, // ':\'), nil, 0,
    @SerNum, MaxFileNameLength, VolFlags, nil, 0) then
  begin
    Result := IntToHex(SerNum, 8);
    Insert('-', Result, 5);
  end
  else
    Result := '';
end;

procedure TDM.DejarUsuario;
begin
  if (Transaccion.Params.Text <> 'read') and (Transaccion.Params.Text <> '')
  then
  begin
    TraerUsuario;
    if Control <> '' then
    begin
      Query.SQL.Text := 'update "Control" set MAQUINA=' + QuotedStr(Maquina) +
        ' where CODIGO=' + Control;
      Query.ExecSQL;
      Query.Transaction.Commit;
    end;
  end;
end;

procedure TDM.TraerUsuario;
begin
  Query.SQL.Text := 'select max(CODIGO) from "Control" where Maquina=' +
    QuotedStr(Maquina);
  Query.Open;
  Control := Query.Fields[0].AsString;
  if Control <> '' then
  begin
    Query.SQL.Text := 'select * from "Control" where CODIGO=' + Control;
    Query.Open;
    Usuario := Query.FieldByName('USUARIO').AsString;
    Query.SQL.Text := 'select PERMISO from "Usuario" where Codigo=' + Usuario;
    Query.Open;
    Permiso := Query.FieldByName('PERMISO').AsInteger;;
  end;
end;

procedure TDM.chequeo;
// var
// L: ShortString;
begin
  {
    //++CHEQUEO
    //Miramos si existe el fichero
    FicheroM:=OpenFileMapping(FILE_MAP_READ,False,'DeG');
    //Si no existe, Error
    if (FicheroM=0) then FicheroM:=OpenFileMapping(FILE_MAP_READ,False,'StO') else
    if (FicheroM=0) then FicheroM:=OpenFileMapping(FILE_MAP_READ,False,'DeG') else
    if (FicheroM=0) then FicheroM:=OpenFileMapping(FILE_MAP_READ,False,'CrE') else
    if (FicheroM=0) then FicheroM:=OpenFileMapping(FILE_MAP_READ,False,'GeS') else
    if (FicheroM=0) then FicheroM:=OpenFileMapping(FILE_MAP_READ,False,'CoN') else
    L := 'Not';
    if (FicheroM<>0) then
    begin
    Compartido:=MapViewOfFile(FicheroM,FILE_MAP_READ,0,0,0);
    L:=Compartido^.Cadena;
    end;
    if (L = 'Try') and ( Usuario = '') then
    begin
    connection;
    TraerUsuario;
    if BaseDatos.Connected = True then BaseDatos.Close;
    end;
    if (L = 'Try') and (Usuario <> '') then connection else
    if (L = 'Rea') and (Usuario <> '') then
    begin
    Licencia:=('HA EXPIRADO EL PERIODO DE PRUEBA '+#13+' PARA MAYOR INFORMACION DIRIJASE A '+#13+'http://www.degsoft.com.ar');
    if Transaccion.Active=True then Transaccion.Active:=False;
    Transaccion.Params.Text:='read consistency';
    connection;
    Transaccion.Active:=True;
    end
    else
    begin
    if BaseDatos.Connected = True then BaseDatos.Close;
    BaseDatos.DatabaseName:='';
    ShowMessage('USTED NO TIENE PERMISO PARA OPERAR EL SISTEMA');
    end; }
end;

procedure TDM.DataModuleCreate(Sender: TObject);
begin
  Usuario := '0';
  Oculto := '0';
  if U = '' then
    U := ExtractFileDrive(Application.ExeName);
  Maquina := GetVolumeID(U);
  connection;
  ConfigQuery.SQL.Text := 'SELECT * FROM "Config"' +
    ' INNER JOIN "Imprimir" ON ("Config"."ImprimirTipo" = "Imprimir".CODIGO)' +
    ' INNER JOIN "Empresa" ON ("Config"."Empresa" = "Empresa".CODIGO)';
  ConfigQuery.Open;
  Empresa := ConfigQuery.FieldByName('NOMBRE').AsString;
  Fecha := FormatDateTime('mm/dd/yyyy hh:mm:ss', now);
  CUIT := ConfigQuery.FieldByName('CUIT').AsString;
  reporte := ConfigQuery.FieldByName('Reporte').AsString;
  IngresosBrutos := ConfigQuery.FieldByName('IIBB').AsString;
  if IngresosBrutos='' then IngresosBrutos:='0';

  Descargar('https://raw.githubusercontent.com/DeGsoft/GeN-XE7/master/Instalador/Update.iss'
  , Path+'Update.iss');

end;

procedure TDM.connection;
var
  IniFile: TIniFile;
  // ?  dia: Integer;
  // ?  fech: tdate;
  bd : string;
begin
  with FormatSettings do
  begin
    DecimalSeparator := '.';
    ThousandSeparator := ',';
    ShortDateFormat := 'mm/dd/yyyy';
  end;
  if BaseDatos.Connected = True then
    BaseDatos.Close;
  // Obtiene la ruta y el nombre de la base de datos

  Path := ExtractFilePath(Application.ExeName);
  Path := StringReplace(Path, 'bin\', '', [rfReplaceAll]);
//  IniFile := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'DeG');
  IniFile := TIniFile.Create((Path+'db\') + 'DeG');
  U := ExtractFileDrive(Application.ExeName);
  bd := IniFile.ReadString('BD', 'Path', '');
  if bd<>'' then Path := bd;
//  if Path = '' then
//  begin
//    Path := ExtractFilePath(Application.ExeName);
//    Path := StringReplace(Path, 'bin\', '', [rfReplaceAll]);
//  end;
  BasedeDatos := IniFile.ReadString('BD', 'DBase', '');
  if BasedeDatos = '' then
  begin
    BasedeDatos := Path + 'db\GeN.FDB';
  end;
  If BasedeDatos = '' then
    ShowMessage('Error al cargar Base de Datos');
  BaseDatos.DatabaseName := BasedeDatos;
  {
    if Gratis(ExtractFileName(Application.ExeName)) <> True then
    //NO ES GRATIS
    begin
    //licencia
    if IniFile.ReadString('Licencia','Tipo','') <> Maquina then
    begin
    dia:= strtoint(IniFile.ReadString('Licencia','Dia',''));
    fech:= StrToDate(IniFile.ReadString('Licencia','Fecha',''));
    if dia > 31 then
    begin
    showmessage('EL PERIODO DE LICENCIA HA TERMINADO.'+#13+'LOS ERRORES QUE SE LE PRESENTEN ES DEBIDO HA ELLO.'+#13+'POR FAVOR COMUNIQUESE A:'+#13+'consultas@degsoft.com.ar');
    if Transaccion.Active=True then Transaccion.Active:=False;
    Transaccion.Params.Text:= 'read';//'concurrency'+#13+'nowait'+#13+'read';
    end
    else
    if fech <> date then
    begin
    IniFile.WriteString('Licencia','Dia',inttostr(dia+1));
    IniFile.WriteString('Licencia','Fecha',datetostr(date));
    end;
    end;
    end;
  }
  BaseDatos.Open;
  // if Transaccion.Active=False then Transaccion.Active:=True;
  IniFile.Destroy;
  // Obtiene la ruta y el nombre de la base de datos
//  IniFile := TIniFile.Create(ExtractFilePath(Application.ExeName) +
//    'Datos.ini');
//  Unidad := IniFile.ReadString('ACTUALIZA', 'Unidad', '');
end;

function TDM.ObtenerConfig;
begin
  ConfigQuery.Close;
  ConfigQuery.Open;
  result := ConfigQuery.FieldByName(campo).Value;
end;

procedure TDM.LeerINI;
Var
  IniFile: TIniFile;
begin
  IniFile := TIniFile.Create(Path + 'db\' + 'DeG');
  webUrl := IniFile.ReadString('WEB', 'URL', '');
  webRes := IniFile.ReadString('WEB', 'RES', '');
  webUsr := IniFile.ReadString('WEB', 'USR', '');
  webPsw := IniFile.ReadString('WEB', 'PSW', '');
  webUpd := IniFile.ReadString('WEB', 'UPD', '');
  afipUrl := IniFile.ReadString('AFIP', 'URL', '');
  afipRes := IniFile.ReadString('AFIP', 'RES', '');
  afipUsr := IniFile.ReadString('AFIP', 'USR', '');
  afipPsw := IniFile.ReadString('AFIP', 'PSW', '');
  IniFile.Destroy;
end;

procedure TDM.EscribirINI;
Var
  IniFile: TIniFile;
begin
  IniFile := TIniFile.Create(Path + 'db\' + 'DeG');
  IniFile.WriteString('WEB', 'URL', webUrl);
  IniFile.WriteString('WEB', 'RES', webRes);
  IniFile.WriteString('WEB', 'USR', webUsr);
  IniFile.WriteString('WEB', 'PSW', webPsw);
  IniFile.WriteString('WEB', 'UPD', webUpd);
  IniFile.WriteString('AFIP', 'URL', afipUrl);
  IniFile.WriteString('AFIP', 'RES', afipRes);
  IniFile.WriteString('AFIP', 'USR', afipUsr);
  IniFile.WriteString('AFIP', 'PSW', afipPsw);
  IniFile.Destroy;
  LeerINI;
end;

procedure TDM.VaciarBase;
//Var
//  IniFile: TIniFile;
  // Path, BaseDeDatos: string;
begin
//  IniFile := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'DeG');
//  FormatSettings.ShortDateFormat := 'mm/dd/yyyy';
//  // Obtiene la ruta y el nombre de la base de datos
//  if Path = '' then
//  begin
//    Path := IniFile.ReadString('BD', 'Path', '');
//  end;
//  if Path = '' then
//    Path := ExtractFilePath(Application.ExeName);
//  if BaseDeDatos = '' then
//    BaseDeDatos := IniFile.ReadString('BD', 'DBase', '');
//  if BaseDeDatos = '' then
//    BaseDeDatos := Path + 'GeN.FDB';
//  if BaseDeDatos = '' then
//    ShowMessage('Error al cargar Base de Datos')
//  else
//  begin
    Consulta.Script.Text := 'SET NAMES WIN1252; CONNECT ' + quotedstr(BaseDeDatos)
      + ' USER ''SYSDBA'' PASSWORD ''masterkey''; ' + Consulta.Script.Text;
    Consulta.ExecuteScript;
    ShowMessage('Base de Datos Restaurada con �xito!!!');
//  end;

  webUrl := '';
  webRes := '';
  webUsr := '';
  webPsw := '';
  webUpd := '';
  afipUrl := '';
  afipRes := '';
  afipUsr := '';
  afipPsw := '';
  EscribirINI;

  // IniFile.WriteString('Licencia', 'Dia', inttostr(1));
  // IniFile.WriteString('Licencia', 'Fecha', datetostr(date));

//  IniFile.Destroy;
end;

function TDM.TextoAfecha;
var
Fmt : TFormatSettings;
begin
  fmt.ShortDateFormat:='yyyy/mm/dd';
  fmt.DateSeparator  :='/';
  fmt.ShortTimeFormat :='hh:nn';
  fmt.TimeSeparator  :=':';
  result := StrToDateTime((
    (Copy(StrDate, 1, 4))+'/'+
    (Copy(StrDate, 5, 2))+'/'+
    (Copy(StrDate, 7, 2))+' '+
    (Copy(StrDate, 9, 2))+':'+
    (Copy(StrDate, 11, 2))
  ),Fmt);
end;

function TDM.Descargar;
var
  LResponse: IHTTPResponse;
  LStream: TFileStream;
  LHttpClient: THTTPClient;
begin
//  inherited;
  LHttpClient := THTTPClient.Create;
  try
    // if a "partial" download already exists
    if FileExists(FFileName) then
    begin
      // re-utilize the same file stream, with position on the end of the stream
      LStream := TFileStream.Create(FFileName, fmOpenWrite or fmShareDenyNone);
    end else begin
      // create a new file stream, with the position on the beginning of the stream
      LStream := TFileStream.Create(FFileName, fmCreate);
    end;
    try
      LResponse := LHttpClient.Get(FURL, LStream);
      result:= FFileName;
      LStream.Free;
    except
//      MessageDlg('Error Get', mtInformation, [mbOK], 0);
   end;
  finally
    LHttpClient.Free;
  end;
end;

// Lee un archivo de texto y lo devuelve como un arreglo.
function TDM.ReadTextFile;
var
   F : TextFile;
   i : Integer;
//   Buffer, version, b1,b2,b3,b4 : String;
begin
   try
      FileMode := fmOpenRead;
      AssignFile(F, FileName);
      Reset(F);
      i := 0;
      REPEAT
          Readln(F, Result);
          Inc(i);
      UNTIL i = 5;
          CloseFile(F);
   except
//      MessageDlg('Error de I/O', mtInformation, [mbOK], 0);
   end;
end;

end.
