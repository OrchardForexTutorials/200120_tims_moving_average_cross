/*
	Tims MA Cross.mq4
	
	Copyright 2019, Novateq Pty Ltd
	https://orchardforex.com
	
	*/
	
//
//	Version and Copyright
//
#define __VERSION__			"1.10"
#define __YEAR__			"2020"
#define __FIRST_YEAR__	"2012"
#define __COPYRIGHT__	"Copyright " + __FIRST_YEAR__ + "-" + __YEAR__ + ", Orchard Forex"
#define __LINK__			"https://orchardforex.com"

#property	copyright		__COPYRIGHT__
#property	link				__LINK__
#property	version			__VERSION__
#property	description		"Combined indicator for use with Tim's MA Cross strategy"
#property	description		"Strategy originally documented at https://youtu.be/a0xdZD1zZXM"
#property	strict

#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   6

//--- plot Baseline
#property indicator_label1  "Slow MA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrWhite
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot High
#property indicator_label2  "ATR High"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGreen
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- plot Mid
#property indicator_label3  "Fast MA"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- plot Low
#property indicator_label4  "ATR Low"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrGreen
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- plot ATR
#property indicator_label5  "ATR"
#property indicator_type5   DRAW_NONE

//--- plot VolumeAv
#property indicator_label6  "Vol%"
#property indicator_type6   DRAW_NONE

#define		CLR_TP	clrYellow
#define		CLR_SL	clrRed

//---	Inputs
input	int				InpBaselineBars	=	100;			// Baseline bars
input	ENUM_MA_METHOD	InpBaselineMethod	=	MODE_SMA;	// Baseline method

input	int				InpFastBars			=	20;			// Fast bars
input	ENUM_MA_METHOD	InpFastMethod		=	MODE_EMA;	// Fast method

input	int				InpATRBars			=	14;			//	ATR Bars
input	double			InpATRMultiplier	=	1.0;			//	ATR Channel Multiplier

input	int				InpVolBars			=	20;			//	Volume average bars
input	double			InpVolFullPct		=	100.0;		//	Full trade volume %
//input	double			InpFullSize			=	0.04;			//	Full size lots
input	double			InpVolHalfPct		=	75.0;			//	Half trade volume %
//input	double			InpHalfSize			=	0.02;			//	Half size lots

input	double			InpStopLossMultiplier	=	1.5;	//	Stop loss multiplier
input	double			InpTakeProfitMultiplier	=	1.0;	// Take Profit Multiplier

//--- indicator buffers
double         BaselineBuffer[];
double         HighBuffer[];
double         MidBuffer[];
double         LowBuffer[];

double			ATRBuffer[];
double			VolBuffer[];

datetime			CurrentBarTime;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {

//--- indicator buffers mapping
   SetIndexBuffer(0,BaselineBuffer);
   SetIndexBuffer(1,HighBuffer);
   SetIndexBuffer(2,MidBuffer);
   SetIndexBuffer(3,LowBuffer);
   SetIndexBuffer(4,ATRBuffer);
   SetIndexBuffer(5,VolBuffer);

	//ArraySetAsSeries(ATRBuffer, true);   

//---
	CurrentBarTime		=	0;
	
//---
   return(INIT_SUCCEEDED);

}

void OnDeinit(const int reason) {

	for (int k = 0; k <= 20; k++) {
		ObjectDelete(StringFormat("Take Profit %i", k));
		ObjectDelete(StringFormat("Stop Loss %i", k));
	}
   
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {

//---

	if (rates_total==prev_calculated) return(rates_total);
	//if	(CurrentBarTime==Time[0])	return(rates_total);
	//CurrentBarTime	=	Time[0];
	
	// Make sure we have enough
   if	(	rates_total	<	InpBaselineBars-1 ||
   		rates_total	<	InpFastBars-1		||
   		rates_total	<	InpATRBars-1		||
   		rates_total <	InpVolBars-1) {
		return(0);
	}

	//ArraySetAsSeries(BaselineBuffer, false);
	//ArraySetAsSeries(HighBuffer, false);
	//ArraySetAsSeries(MidBuffer, false);
	//ArraySetAsSeries(LowBuffer, false);
	
	//	Initialise the buffers if needed
	if (prev_calculated==0) {
		ArrayInitialize(BaselineBuffer, 0);
		ArrayInitialize(HighBuffer, 0);
		ArrayInitialize(MidBuffer, 0);
		ArrayInitialize(LowBuffer, 0);
		ArrayInitialize(ATRBuffer, 0);
		ArrayInitialize(VolBuffer, 0);
	}
	
	CalculateMA(rates_total, prev_calculated, InpBaselineBars, InpBaselineMethod, PRICE_CLOSE, BaselineBuffer);
	CalculateMA(rates_total, prev_calculated, InpFastBars, InpFastMethod, PRICE_CLOSE, MidBuffer);
	
	//if (ArraySize(ATRBuffer)<ArraySize(MidBuffer)) {
	//	ArraySetAsSeries(ATRBuffer, false);
	//	ArrayResize(ATRBuffer, ArraySize(MidBuffer));
	//	ArraySetAsSeries(ATRBuffer, true);
	//}

	CalculateATR(rates_total, prev_calculated, InpATRBars, ATRBuffer);
	CalculateVol(rates_total, prev_calculated, InpVolBars, VolBuffer);
	CalculateChannel(rates_total, prev_calculated, 1, InpATRMultiplier, MidBuffer, ATRBuffer, HighBuffer);
	CalculateChannel(rates_total, prev_calculated, -1, InpATRMultiplier, MidBuffer, ATRBuffer, LowBuffer);

	double	profitPrice;
	double	lossPrice;	
	int	limit	=	rates_total	-	prev_calculated;
   if (prev_calculated>0)	limit++;
	for (int i = 1, j = 0, k = 0; i<limit && k < 20; i++) {
		profitPrice	=	0;
		lossPrice	=	0;
		if (BaselineBuffer[i]<MidBuffer[i]) {	// Up trend
			if (Open[i]<MidBuffer[i] && Close[i]>MidBuffer[i] && High[i]<=HighBuffer[i]) {
				profitPrice	=	Close[i]+(ATRBuffer[i]*InpTakeProfitMultiplier);
				lossPrice	=	Close[i]-(ATRBuffer[i]*InpStopLossMultiplier);
			}
		} else {
			if (Open[i]>MidBuffer[i] && Close[i]<MidBuffer[i] && Low[i]>=LowBuffer[i]) {
				profitPrice	=	Close[i]-(ATRBuffer[i]*InpTakeProfitMultiplier);
				lossPrice	=	Close[i]+(ATRBuffer[i]*InpStopLossMultiplier);
			}
		}
		if (profitPrice>0 && (VolBuffer[i]*100>=InpVolHalfPct)) {
			ENUM_LINE_STYLE	style	=	(VolBuffer[i]*100>=InpVolFullPct) ? STYLE_SOLID : STYLE_DOT;
			if (j==0) {
				DrawLineRight(StringFormat("Take Profit %i", k), Time[i], profitPrice, Time[j], profitPrice, CLR_TP, style);
				DrawLineRight(StringFormat("Stop Loss %i", k), Time[i], lossPrice, Time[j], lossPrice, CLR_SL, style);
			} else {
				DrawLine(StringFormat("Take Profit %i", k), Time[i], profitPrice, Time[j], profitPrice, CLR_TP, style);
				DrawLine(StringFormat("Stop Loss %i", k), Time[i], lossPrice, Time[j], lossPrice, CLR_SL, style);
			}
			j	=	i;
			k++;
		}
	}
	//CurrentBarTime	=	Time[0];


//--- return value of prev_calculated for next call
   return(rates_total);
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+

//
//	Calculate the moving average buffer
//
void CalculateMA(int rates_total, int prev_calculated, int period, ENUM_MA_METHOD method, ENUM_APPLIED_PRICE price, double &buffer[]) {

	int	limit	=	rates_total	-	prev_calculated;
   if (prev_calculated>0)	limit++;
	
	for (int i = limit-1; i>=0; i--) {
		buffer[i]	=	iMA(Symbol(), Period(), period, 0, method, price, i);
	}
	
	return;

}

//
//	Calculate the ATR buffer
//
void CalculateATR(int rates_total, int prev_calculated, int period, double &buffer[]) {

	int	limit	=	rates_total	-	prev_calculated;
   if (prev_calculated>0)	limit++;
	
	for (int i = limit-1; i>=0; i--) {
		buffer[i]	=	iATR(Symbol(), Period(), period, i);
	}
	
	return;

}

//
//	Calculate the Volume % buffer
//
void CalculateVol(int rates_total, int prev_calculated, int period, double &buffer[]) {

	int	limit	=	rates_total	-	prev_calculated;
   if (prev_calculated>0)	limit++;

	if (limit>(rates_total-period)) limit = (rates_total-period);
	
	for (int i = limit-1; i>=0; i--) {
		long	vol	=	0;
		for (int j = 0; j<period; j++) {
			vol	+=	Volume[j+i];
		}
		double	avVol	=	(double)(vol / period);
		buffer[i]	=	(double)(Volume[i]/avVol);
	}
	
	return;

}

//
//	Calculate the Channel buffer
//
void CalculateChannel(int rates_total, int prev_calculated, double direction, double multiplier, const double &midBuffer[], const double & atrBuffer[], double &buffer[]) {

	int	limit	=	rates_total	-	prev_calculated;
   if (prev_calculated>0)	limit++;
	
	for (int i = limit-1; i>=0; i--) {
		buffer[i]	=	midBuffer[i] + (atrBuffer[i]*multiplier*direction);
	}
	
	return;

}

//
//	DrawLineRight
//	Draws a ray line ajm
//
void DrawLineRight(string name, datetime time1, double price1, datetime time2, double price2) {

	DrawLineRight(name, time1, price1, time2, price2, clrGray, STYLE_SOLID);
	return;
	
}

void DrawLineRight(string name, datetime time1, double price1, datetime time2, double price2, int clr, int style) {

   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);

	return;
	
}

//
//	DrawLine
//	Just draws a trend line
//
void DrawLine(string name, datetime time1, double price1, datetime time2, double price2, int clr) {
   
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
}

void DrawLine(string name, datetime time1, double price1, datetime time2, double price2, int clr, int style) {

   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);

	return;
	
}

