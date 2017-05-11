unit BuscaFactura;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, DB, ADODB, StdCtrls, Buttons, Grids, DBGrids, DataModule, ExtCtrls,
  jpeg, ImprimirDM, IBX.IBCustomDataSet, IBX.IBQuery;

type
  TBuscaFacturaForm = class(TForm)
    DS: TDataSource;
    Panel1: TPanel;
    Label2: TLabel;
    ventaEdit: TEdit;
    Panel2: TPanel;
    SiBitBtn: TBitBtn;
    Tabla: TIBQuery;
    LetraEdit: TEdit;
    Label1: TLabel;
    DBGrid1: TDBGrid;
    todoBitBtn: TBitBtn;
    Image1: TImage;
    Presupuesto: TCheckBox;
    Label4: TLabel;
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure DBGrid1DblClick(Sender: TObject);
    procedure DBGrid1KeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormDestroy(Sender: TObject);
    procedure NoBitBtnClick(Sender: TObject);
    procedure SiBitBtnClick(Sender: TObject);
    procedure todoBitBtnClick(Sender: TObject);
    procedure Image1Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    Codigo, CodProve, Tipo: String;
    Cancela: boolean;
  end;

var
  BuscaFacturaForm: TBuscaFacturaForm;

implementation

{$R *.dfm}

procedure TBuscaFacturaForm.FormKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  nro, let: string;
begin
  if not DBGrid1.Focused = True then
  begin
    nro := ventaEdit.Text;
    let := LetraEdit.Text;
    if Presupuesto.Checked then
    begin
      ImprimirDataModule := TImprimirDataModule.Create(self);
      Tabla.SQL.Text := 'SELECT ' + ImprimirDataModule.PRE(nro, let);
      ImprimirDataModule.Free;
    end
    else
      Tabla.SQL.Text := 'SELECT ' +
        QuotedStr(dm.ConfigQuery.FieldByName('NOMBRE').AsString) +
        ' As Empresa,' + '  "Cliente".NOMBRE,' + '  "Cliente".TITULAR,' +
        '  "Cliente".DIRECCION,' + '  "Cliente".DIRECCIONCOMERCIAL,' +
        '  "Articulo".DESCRIPCION,' + '  "VentaItem".OPERACION,' +
        '  "VentaItem".ARTICULO,' + '  "VentaItem".CANTIDAD,' +
        '  "VentaItem".PRECIO,' +
        '  ("VentaItem".PRECIO * "VentaItem".CANTIDAD ) as PREXCANT,' +
        '  "VentaItem".SERVICIO,' + '  "VentaItem".DESCRIPCION AS DESCR,' +
        '  "Venta".CODIGO,' + '  "Venta".LETRA,' + '  "Venta".FECHA,' +
        '  "Venta".COMPROBANTE,' + '  "Venta".IVA3,' + '  "Venta".TOTAL,' +
        '  "Venta".CONTADO,' + '  "Venta".CLIENTE,' + '  "Venta".SUBTOTAL,' +
        '  "Venta".DESCUENTO,' + '  "Venta".IMPUESTO,' + '  "Venta".IVA2,' +
        '  "Venta".IVA1,' + '  "Venta".EXCENTO,' + '  "Venta".SALDO,' +
        '  "Venta".PAGADO' + ' FROM' + '  "Venta"' +
        '  INNER JOIN "VentaItem" ON ("Venta".CODIGO = "VentaItem".OPERACION)' +
        '  INNER JOIN "Articulo" ON ("VentaItem".ARTICULO = "Articulo".CODIGO)'
        + '  INNER JOIN "Cliente" ON ("Venta".CLIENTE = "Cliente".CODIGO)' +
        '  WHERE' + '  ("Venta".CODIGO like ' + QuotedStr(nro + '%') + '  ) AND'
        + '  ("Venta".LETRA like ' + QuotedStr(let + '%') + '  )';
    Tabla.Open;
  end;
  if Key = VK_Escape then
    Close;
end;

procedure TBuscaFacturaForm.FormShow(Sender: TObject);
begin
  // dm := tdm.Create(self);
end;

procedure TBuscaFacturaForm.Image1Click(Sender: TObject);
begin
  ImprimirDataModule := TImprimirDataModule.Create(self);
  ImprimirDataModule.CSV(Tabla.SQL.Text, 'VENTAS');
  ImprimirDataModule.Free;
end;

procedure TBuscaFacturaForm.NoBitBtnClick(Sender: TObject);
begin
  Cancela := True;
  Codigo := '';
  Close;
end;

procedure TBuscaFacturaForm.SiBitBtnClick(Sender: TObject);
var
  nro, let: string;
begin
  // IMPRIMIR
  if (dm.ConfigQuery.FieldByName('Imprimir').AsString) <> 'NO' then
  begin
    nro := Tabla.FieldByName('CODIGO').AsString;
    let := Tabla.FieldByName('LETRA').AsString;
    ImprimirDataModule := TImprimirDataModule.Create(self);
    if Presupuesto.Checked then
      with ImprimirDataModule do
        Impr(ImprimirDataModule.PRE(nro, let), 'Presupuesto')
    else
      with ImprimirDataModule do
        Impr(ImprimirDataModule.VTA(nro, let), '');
    ImprimirDataModule.Free;
  end;
  Close;
end;

procedure TBuscaFacturaForm.todoBitBtnClick(Sender: TObject);
begin
  if Presupuesto.Checked then
  begin
    ImprimirDataModule := TImprimirDataModule.Create(self);
    Tabla.SQL.Text := 'SELECT ' + ImprimirDataModule.presupuestoSql;
    ImprimirDataModule.Free;
  end
  else
    Tabla.SQL.Text := 'SELECT ' + QuotedStr(dm.ConfigQuery.FieldByName('NOMBRE')
      .AsString) + ' As Empresa,' + '  "Cliente".NOMBRE,' +
      '  "Cliente".TITULAR,' + '  "Cliente".DIRECCION,' +
      '  "Cliente".DIRECCIONCOMERCIAL,' + '  "Articulo".DESCRIPCION,' +
      '  "VentaItem".OPERACION,' + '  "VentaItem".ARTICULO,' +
      '  "VentaItem".CANTIDAD,' + '  "VentaItem".PRECIO,' +
      '  ("VentaItem".PRECIO * "VentaItem".CANTIDAD ) as PREXCANT,' +
      '  "VentaItem".SERVICIO,' + '  "VentaItem".DESCRIPCION AS DESCR,' +
      '  "Venta".CODIGO,' + '  "Venta".LETRA,' + '  "Venta".FECHA,' +
      '  "Venta".COMPROBANTE,' + '  "Venta".IVA3,' + '  "Venta".TOTAL,' +
      '  "Venta".CONTADO,' + '  "Venta".CLIENTE,' + '  "Venta".SUBTOTAL,' +
      '  "Venta".DESCUENTO,' + '  "Venta".IMPUESTO,' + '  "Venta".IVA2,' +
      '  "Venta".IVA1,' + '  "Venta".EXCENTO,' + '  "Venta".SALDO,' +
      '  "Venta".PAGADO' + ' FROM' + '  "Venta"' +
      '  INNER JOIN "VentaItem" ON ("Venta".CODIGO = "VentaItem".OPERACION)' +
      '  INNER JOIN "Articulo" ON ("VentaItem".ARTICULO = "Articulo".CODIGO)' +
      '  INNER JOIN "Cliente" ON ("Venta".CLIENTE = "Cliente".CODIGO)' + '';
  Tabla.Open;
end;

procedure TBuscaFacturaForm.DBGrid1DblClick(Sender: TObject);
begin
  SiBitBtnClick(DBGrid1);
end;

procedure TBuscaFacturaForm.DBGrid1KeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  IF Key = VK_DOWN then
    DBGrid1.SetFocus;
end;

procedure TBuscaFacturaForm.FormCreate(Sender: TObject);
begin
  dm.ConfigQuery.Open;
end;

procedure TBuscaFacturaForm.FormDestroy(Sender: TObject);
begin
  Tabla.Close;
end;

end.