unit DataModule;

interface

uses
  SysUtils, Classes, DB, IniFiles, Windows, Controls, Forms, Dialogs,
  IBX.IBCustomDataSet, IBX.IBQuery, IBX.IBDatabase;

type

  TDM = class(TDataModule)
    BaseDatos: TIBDatabase;
    Transaccion: TIBTransaction;
    ConfigQuery: TIBQuery;
    Query: TIBQuery;
    procedure DataModuleCreate(Sender: TObject);
  private
    { Private declarations }
  public
    Unidad: string;
    // Gratis:boolean;
    IniFile: TIniFile;
    procedure connection;
    procedure chequeo;
    procedure TraerUsuario;
    procedure DejarUsuario;
    function ExecuteProcess(ProcessName, Path: String): Cardinal;
    {function Gratis(arch: String): boolean;}
    { Public declarations }
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
  Usuario, Licencia, U, Path, Oculto, Control, Maquina, Fecha, Empresa: string;
  Permiso: Integer;
  LoginOK, Cancelar: boolean;
  detalle, memo, BasedeDatos, mode: string; // revisar

implementation

{$R *.dfm}

{function TDM.Gratis;
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
end;}

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
  if (Transaccion.Params.Text <> 'read') and (Transaccion.Params.Text <> '') then
  begin
    TraerUsuario;
    if Control <> '' then
    begin
    Query.SQL.Text := 'update "Control" set MAQUINA=' + QuotedStr(Maquina)
      + ' where CODIGO=' + Control;
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
    Query.SQL.Text := 'select PERMISO from "Usuario" where Codigo='
      + Usuario;
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
end;

procedure TDM.connection;
Var
  IniFile: TIniFile;
  // ?  dia: Integer;
  // ?  fech: tdate;
begin
  with FormatSettings do
  begin
    DecimalSeparator := '.';
    ThousandSeparator := '.';
    ShortDateFormat := 'mm/dd/yyyy';
  end;
  if BaseDatos.Connected = True then
    BaseDatos.Close;
  // Obtiene la ruta y el nombre de la base de datos
  IniFile := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'DeG');
  U := ExtractFileDrive(Application.ExeName);
  Path := IniFile.ReadString('BD', 'Path', '');
  if Path = '' then
    Path := ExtractFilePath(Application.ExeName);
  BasedeDatos := IniFile.ReadString('BD', 'DBase', '');
  if BasedeDatos = '' then
    BasedeDatos := Path + 'GeN.FDB';
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
  IniFile := TIniFile.Create(ExtractFilePath(Application.ExeName) +
    'Datos.ini');
  Unidad := IniFile.ReadString('ACTUALIZA', 'Unidad', '');
end;

end.
