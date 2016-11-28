object Form1: TForm1
  Left = 381
  Top = 219
  Width = 436
  Height = 344
  Caption = 'Form1'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object btnStart: TButton
    Left = 48
    Top = 24
    Width = 75
    Height = 25
    Caption = 'start'
    TabOrder = 0
    OnClick = btnStartClick
  end
  object MemoLog: TMemo
    Left = 0
    Top = 104
    Width = 428
    Height = 213
    Align = alBottom
    ScrollBars = ssBoth
    TabOrder = 1
  end
end
