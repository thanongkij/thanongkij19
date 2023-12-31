//+------------------------------------------------------------------+
//|                                             Davin Auto TP SL TS.mq4|
//|                              Copyright 2023, Thanongkij |
//+------------------------------------------------------------------+
#property copyright "ForexBookThai"
#property link      "LineID: https://lin.ee/Kehi7N5"
#property version   "3.3"
#property strict
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/* 
   v1.0
   + Auto SL and TP
   
   v1.22
   + Correcting Min Stop Level
   
   v2.0
   + Added modes for SL and TP (Hidden or Placed)
   + Added profit lock
   + Added stepping Trailing Stop
   
   v2.01
   + Added option to enable/disable alert when closed by hidden sl/tp
   
   v2.03
   + Fixed initial locking profit
   + Fixed trailing stop
   
   v2.04
   + Fixed trailing stop step
   + Rearrange lock profit to a function
   
   v2.05
   + Added Trailing Stop Method (Classic, Step Keep Distance, Step By Step)
   
   v2.06
   + Added Option to Enable/Disable Profit Lock
  
  NOTE:
  + First of all, your orders SL and TP must be set to 0, then this EA will set appropriate SL and TP.
  + To disable SL, TP, Profit Lock, and Trailing Stop, set its value to 0.
*/

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


enum ENUM_CHARTSYMBOL
  {
   CurrentChartSymbol=0,//Current Chart Only
   AllOpenOrder=1,//All Opened Orders
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_SLTP_MODE
  {
   Server=0,//Place SL n TP
   Client=1,//Hidden SL n TP
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_LOCKPROFIT_ENABLE
  {
   LP_DISABLE=0,//Disable
   LP_ENABLE=1,//Enable
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_TRAILINGSTOP_METHOD
  {
   TS_NONE=0,//No Trailing Stop
   TS_CLASSIC=1,//Classic
   TS_STEP_DISTANCE=2,//Step Keep Distance
   TS_STEP_BY_STEP=3, //Step By Step
  };
string STR_OPTYPE[]={"Buy","Sell","Buy Limit","Sell Limit","Buy Stop","Sell Stop"};


input    double                     multi       = 2;      //Multiply Order
input    int                        StopLoss    = 300;    //Stop Loss
input    bool                       riskreward  = false;  //Use Risk Reward Ratio
input    double                     rr1         = 0.2;   //Reward Risk (1)
input    double                     rr2         = 1;     //Reward Risk (2)
input    double                     rr3         = 2;     //Reward Risk (3)
input    bool                       breakeven   = false;     //Breakeven
input    int                        breakeven_  = 30;     //Breakeven Point

sinput   string                     note1       ="";//-=[ SL & TP SETTINGS ]=-
    int                        TakeProfit  =0;//Take Profit

input    ENUM_SLTP_MODE             SLnTPMode   =Server;//SL & TP Mode

sinput   string                     note2             ="";//-=[ PROFIT LOCK SETTINGS ]=-
input    ENUM_LOCKPROFIT_ENABLE     LockProfitEnable  =LP_ENABLE;//Enable/Disable Profit Lock
input    int                        LockProfitAfter   =100;//Target Points to Lock Profit
input    int                        ProfitLock        =60;//Profit To Lock

sinput   string                     note3             ="";//-=[ TRAILING STOP SETTINGS ]=-
input    ENUM_TRAILINGSTOP_METHOD   TrailingStopMethod=TS_NONE;//Trailing Method
input    int                        TrailingStop      =50;//Trailing Stop
input    int                        TrailingStep      =10;//Trailing Stop Step

sinput   string                     note4                ="";//-=[ OTHER SETTINGS ]=-
    ENUM_CHARTSYMBOL           ChartSymbolSelection =CurrentChartSymbol;//
input    bool                       inpEnableAlert       =false;//Enable Alert


int magic= 1234;

//-------------------------- Block Account ID --------------//

bool BlockAccount = false; // True = ให้ใช้ได้เฉพาะ id  False=ไม่เปิดการบล็อคid(หมายถึงใช้ได้ทุกบัญชี)

int AccountID = 123456;

//--------------------- Block AccountDemo Only --------------//

bool AccountDemo = false;  // true = ให้ใช้ได้เฉพาะ demo   false=ไม่เปิดการบล็ อคdemo

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
int OnInit()
  {
   if(BlockAccount && AccountNumber() != AccountID)
     {
      Comment("Account ID Wrong !...please contact administrator");
      return(0);
     }
   else
      if(AccountDemo && IsDemo() != true)
        {
         Comment("EA use for account demo only !... ");
         return(0);
        }












//+------------------------------------------------------------------+
//| Calculate Open Positions                                           |
//+------------------------------------------------------------------+
int CalculateCurrentOrders()
  {
   int buys=0,sells=0;
//---
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(ChartSymbolSelection==CurrentChartSymbol && OrderSymbol()!=Symbol()) continue;
      if(OrderType()==OP_BUY)
         buys++;
      if(OrderType()==OP_SELL)
         sells++;
     }

   if(buys>0) return(buys);
   else       return(-sells);
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool LockProfit(int TiketOrder,int TargetPoints,int LockedPoints)
  {
   if(LockProfitEnable==False || TargetPoints==0 || LockedPoints==0) return false;

   if(OrderSelect(TiketOrder,SELECT_BY_TICKET,MODE_TRADES)==false) return false;

   double CurrentSL=(OrderStopLoss()!=0)?OrderStopLoss():OrderOpenPrice();
   double point=MarketInfo(OrderSymbol(),MODE_POINT);
   int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS);
   double minstoplevel=MarketInfo(OrderSymbol(),MODE_STOPLEVEL);
   double ask=MarketInfo(OrderSymbol(),MODE_ASK);
   double bid=MarketInfo(OrderSymbol(),MODE_BID);
   double PSL=0;

   if((OrderType()==OP_BUY) && (bid-OrderOpenPrice()>=TargetPoints*point) && (CurrentSL<=OrderOpenPrice()))
     {
      PSL=NormalizeDouble(OrderOpenPrice()+(LockedPoints*point),digits);
     }
   else if((OrderType()==OP_SELL) && (OrderOpenPrice()-ask>=TargetPoints*point) && (CurrentSL>=OrderOpenPrice()))
     {
      PSL=NormalizeDouble(OrderOpenPrice()-(LockedPoints*point),digits);
     }
   else
      return false;

   Print(STR_OPTYPE[OrderType()]," #",OrderTicket()," ProfitLock: OP=",OrderOpenPrice()," CSL=",CurrentSL," PSL=",PSL," LP=",LockedPoints);

   if(OrderModify(OrderTicket(),OrderOpenPrice(),PSL,OrderTakeProfit(),0,clrRed))
      return true;
   else
      return false;


   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool RZ_TrailingStop(int TiketOrder,int JumlahPoin,int Step=1,ENUM_TRAILINGSTOP_METHOD Method=TS_STEP_DISTANCE)
  {
   if(JumlahPoin==0) return false;

   if(OrderSelect(TiketOrder,SELECT_BY_TICKET,MODE_TRADES)==false) return false;

   double CurrentSL=(OrderStopLoss()!=0)?OrderStopLoss():OrderOpenPrice();
   double point=MarketInfo(OrderSymbol(),MODE_POINT);
   int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS);
   double minstoplevel=MarketInfo(OrderSymbol(),MODE_STOPLEVEL);
   double ask=MarketInfo(OrderSymbol(),MODE_ASK);
   double bid=MarketInfo(OrderSymbol(),MODE_BID);
   double TSL=0;

   JumlahPoin=JumlahPoin+(int)minstoplevel;

   if((OrderType()==OP_BUY) && (bid-OrderOpenPrice()>JumlahPoin*point))
     {
      if(CurrentSL<OrderOpenPrice())
         CurrentSL=OrderOpenPrice();

      if((bid-CurrentSL)>=JumlahPoin*point)
        {
         switch(Method)
           {
            case TS_CLASSIC://Classic, no step
               TSL=NormalizeDouble(bid-(JumlahPoin*point),digits);
               break;
            case TS_STEP_DISTANCE://Step keeping distance
               TSL=NormalizeDouble(bid-((JumlahPoin-Step)*point),digits);
               break;
            case TS_STEP_BY_STEP://Step by step (slow)
               TSL=NormalizeDouble(CurrentSL+(Step*point),digits);
               break;
            default:
               TSL=0;
           }
        }
     }

   else if((OrderType()==OP_SELL) && (OrderOpenPrice()-ask>JumlahPoin*point))
     {
      if(CurrentSL>OrderOpenPrice())
         CurrentSL=OrderOpenPrice();

      if((CurrentSL-ask)>=JumlahPoin*point)
        {
         switch(Method)
           {
            case TS_CLASSIC://Classic
               TSL=NormalizeDouble(ask+(JumlahPoin*point),digits);
               break;
            case TS_STEP_DISTANCE://Step keeping distance
               TSL=NormalizeDouble(ask+((JumlahPoin-Step)*point),digits);
               break;
            case TS_STEP_BY_STEP://Step by step (slow)
               TSL=NormalizeDouble(CurrentSL-(Step*point),digits);
               break;
            default:
               TSL=0;
           }
        }
     }

   if(TSL==0)
      return false;

   Print(STR_OPTYPE[OrderType()]," #",OrderTicket()," TrailingStop: OP=",OrderOpenPrice()," CSL=",CurrentSL," TSL=",TSL," TS=",JumlahPoin," Step=",Step);
   bool res=OrderModify(OrderTicket(),OrderOpenPrice(),TSL,OrderTakeProfit(),0,clrRed);
   if(res == true) return true;
   else return false;

   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SetSLnTP()
  {
   double SL,TP;
   SL=TP=0.00;

   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(ChartSymbolSelection==CurrentChartSymbol && OrderSymbol()!=Symbol()) continue;

      double point=MarketInfo(OrderSymbol(),MODE_POINT);
      double minstoplevel=MarketInfo(OrderSymbol(),MODE_STOPLEVEL);
      double ask=MarketInfo(OrderSymbol(),MODE_ASK);
      double bid=MarketInfo(OrderSymbol(),MODE_BID);
      int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS);

      //Print("Check SL & TP : ",OrderSymbol()," SL = ",OrderStopLoss()," TP = ",OrderTakeProfit());

      double ClosePrice=0;
      int Points=0;
      color CloseColor=clrNONE;

      //Get Points
      if(OrderType()==OP_BUY)
        {
         CloseColor=clrBlue;
         ClosePrice=bid;
         Points=(int)((ClosePrice-OrderOpenPrice())/point);
        }
      else if(OrderType()==OP_SELL)
        {
         CloseColor=clrRed;
         ClosePrice=ask;
         Points=(int)((OrderOpenPrice()-ClosePrice)/point);
        }

      //Set Server SL and TP
      if(SLnTPMode==Server)
        {
         if(OrderType()==OP_BUY)
           {
            SL=(StopLoss>0)?NormalizeDouble(OrderOpenPrice()-((StopLoss+minstoplevel)*point),digits):0;
            TP=(TakeProfit>0)?NormalizeDouble(OrderOpenPrice()+((TakeProfit+minstoplevel)*point),digits):0;
           }
         else if(OrderType()==OP_SELL)
           {
            SL=(StopLoss>0)?NormalizeDouble(OrderOpenPrice()+((StopLoss+minstoplevel)*point),digits):0;
            TP=(TakeProfit>0)?NormalizeDouble(OrderOpenPrice()-((TakeProfit+minstoplevel)*point),digits):0;
           }

         if(OrderStopLoss()==0.0 && OrderTakeProfit()==0.0)
            bool res=OrderModify(OrderTicket(),OrderOpenPrice(),SL,TP,0,Blue);
         else if(OrderTakeProfit()==0.0)
            bool res=OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),TP,0,Blue);
         else if(OrderStopLoss()==0.0)
            bool res=OrderModify(OrderTicket(),OrderOpenPrice(),SL,OrderTakeProfit(),0,Red);
        }
      //Hidden SL and TP
      else if(SLnTPMode==Client)
        {
         if((TakeProfit>0 && Points>=TakeProfit) || (StopLoss>0 && Points<=-StopLoss))
           {
            if(OrderClose(OrderTicket(),OrderLots(),ClosePrice,3,CloseColor))
              {
               if(inpEnableAlert)
                 {
                  if(OrderProfit()>0)
                     Alert("Closed by Virtual TP #",OrderTicket()," Profit=",OrderProfit()," Points=",Points);
                  if(OrderProfit()<0)
                     Alert("Closed by Virtual SL #",OrderTicket()," Loss=",OrderProfit()," Points=",Points);
                 }
              }
           }
        }

      if(LockProfitAfter>0 && ProfitLock>0 && Points>=LockProfitAfter)
        {
         if(Points<=LockProfitAfter+TrailingStop)
           {
            LockProfit(OrderTicket(),LockProfitAfter,ProfitLock);
           }
         else if(Points>=LockProfitAfter+TrailingStop)
           {
            RZ_TrailingStop(OrderTicket(),TrailingStop,TrailingStep,TrailingStopMethod);
           }
        }
      else if(LockProfitAfter==0)
        {
         RZ_TrailingStop(OrderTicket(),TrailingStop,TrailingStep,TrailingStopMethod);
        }

     }

   return false;

  }
  
 
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnInit()
  {

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(Bars<100 || IsTradeAllowed()==false)
      return;

   if(CalculateCurrentOrders()!=0)
      SetSLnTP();

   //

int countB=0; 
int ticker_b1=0;  
int ticker_b2=0;
int ticker_b3=0;
double priceB=10000;

int countS=0;
int ticker_s1=0;  
int ticker_s2=0;
int ticker_s3=0;
double priceS=-10000;

double lotsB=1000000;
double lotsS=1000000;

int countB_M=0;
int countS_M=0;

for(int i=0;i<OrdersTotal(); i++ ){
if(OrderSelect(i, SELECT_BY_POS,MODE_TRADES)==true){ 
if(OrderSymbol()==Symbol() )
{
if (OrderType()==OP_BUY  )
{
      if(OrderMagicNumber()==0)countB_M++;
      countB++;
      if(countB==1)ticker_b1=OrderTicket();
      if(countB==2)ticker_b2=OrderTicket();
      if(countB==3)ticker_b3=OrderTicket();
      if(OrderLots()<lotsB) lotsB=OrderLots();
      if(OrderOpenPrice()<priceB) priceB=OrderOpenPrice();
}

if (OrderType()==OP_SELL )
{
      if(OrderMagicNumber()==0)countS_M++;
      countS++;
      if(countS==1)ticker_s1=OrderTicket();
      if(countS==2)ticker_s2=OrderTicket();
      if(countS==3)ticker_s3=OrderTicket();      
      if(OrderLots()<lotsS) lotsS=OrderLots();
      if(OrderOpenPrice()>priceS) priceS=OrderOpenPrice();
}
}}}

// hiden buy ----------------------------------------------------------------------------------
if( countB>0 &&SLnTPMode==Client)
{

      double tp1=0;
      //double sl1=0;
      if( riskreward &&rr1>0)
      {                 
      tp1=priceB+MarketInfo(Symbol(),MODE_POINT)*StopLoss*rr1;       
      //sl1=priceB-MarketInfo(Symbol(),MODE_POINT)*StopLoss*rr1;       
      }
      double tp2=0;
      if( riskreward &&rr2>0)
      {                 
      tp2=priceB+MarketInfo(Symbol(),MODE_POINT)*StopLoss*rr2;       
      }      
      double tp3=0;
      if( riskreward &&rr3>0)
      {                 
      tp3=priceB+MarketInfo(Symbol(),MODE_POINT)*StopLoss*rr3;       
      }  
if(countB==3 &&Bid>tp1) CloseAll_t(ticker_b1);
if(countB==2 &&Bid>tp2) CloseAll_t(ticker_b1);
if(countB==1 &&Bid>tp3) CloseAll_t(ticker_b1);

if(countB==2 &&breakeven &&Bid<priceB+breakeven_*Point) { CloseAll_t(ticker_b1); CloseAll_t(ticker_b2); }
if(countB==1 &&countB_M==0 &&Bid<tp1) { CloseAll_t(ticker_b1);  }



}
// hiden sell ----------------------------------------------------------------------------------
if( countS>0 &&SLnTPMode==Client)
{

      double tp1=0;
      //double sl1=0;
      if( riskreward &&rr1>0)
      {                 
      tp1=priceS-MarketInfo(Symbol(),MODE_POINT)*StopLoss*rr1;    
      //sl1=priceS+MarketInfo(Symbol(),MODE_POINT)*StopLoss*rr1;   
      }
      double tp2=0;
      if( riskreward &&rr2>0)
      {                 
      tp2=priceS-MarketInfo(Symbol(),MODE_POINT)*StopLoss*rr2;       
      }      
      double tp3=0;
      if( riskreward &&rr3>0)
      {                 
      tp3=priceS-MarketInfo(Symbol(),MODE_POINT)*StopLoss*rr3;       
      }  
if(countS==3 &&Ask<tp1) CloseAll_t(ticker_s1);
if(countS==2 &&Ask<tp2) CloseAll_t(ticker_s1);
if(countS==1 &&Ask<tp3) CloseAll_t(ticker_s1);

if(countS==2 &&breakeven &&Ask>priceS-breakeven_*Point) { CloseAll_t(ticker_s1); CloseAll_t(ticker_s2); }
if(countS==1 &&countS_M==0 &&Ask>tp1) { CloseAll_t(ticker_s1);  }

}
// open sl ----------------------------------------------------------------------------------
if(countB_M==1 &&countB==1)   
{
   if(countB_M==1)
   {
      
      if(lotsB<MarketInfo(Symbol(),MODE_MINLOT)) lotsB=MarketInfo(Symbol(),MODE_MINLOT);
      if(lotsB>MarketInfo(Symbol(),MODE_MAXLOT)) lotsB=MarketInfo(Symbol(),MODE_MAXLOT);
      
      double SL1=0; 
      if(StopLoss>0)  SL1=MarketInfo(Symbol(),MODE_ASK)-MarketInfo(Symbol(),MODE_POINT)*StopLoss;
      SL1=NormalizeDouble(SL1,Digits);
      if(SLnTPMode==Client) SL1=0; 
      
      //double TP1=0;
      //if( riskreward &&rr2>0)
      
      //if(TP>0)  TP1=MarketInfo(Symbol(),MODE_ASK)+MarketInfo(Symbol(),MODE_POINT)*TP; 
         
      int ticket=OrderSend(NULL,OP_BUY,NormalizeDouble(lotsB*multi*1,2),Ask,3,SL1,0,"",magic);
   
   //return;
   
   }
   if(countB_M==1)
   {
      
      if(lotsB<MarketInfo(Symbol(),MODE_MINLOT)) lotsB=MarketInfo(Symbol(),MODE_MINLOT);
      if(lotsB>MarketInfo(Symbol(),MODE_MAXLOT)) lotsB=MarketInfo(Symbol(),MODE_MAXLOT);
      
      double SL1=0; 
      if(StopLoss>0)  SL1=MarketInfo(Symbol(),MODE_ASK)-MarketInfo(Symbol(),MODE_POINT)*StopLoss;
      SL1=NormalizeDouble(SL1,Digits);
      if(SLnTPMode==Client) SL1=0; 
      //double TP1=0;
      //if( riskreward &&rr2>0)
      
      //if(TP>0)  TP1=MarketInfo(Symbol(),MODE_ASK)+MarketInfo(Symbol(),MODE_POINT)*TP; 
         
      int ticket=OrderSend(NULL,OP_BUY,NormalizeDouble(lotsB*multi*multi,2),Ask,3,SL1,0,"",magic);
   
   //return;
   
   }
return;
}
if(countS_M==1 &&countS==1)   
{
   if(countS_M==1)
   {
      
      if(lotsS<MarketInfo(Symbol(),MODE_MINLOT)) lotsS=MarketInfo(Symbol(),MODE_MINLOT);
      if(lotsS>MarketInfo(Symbol(),MODE_MAXLOT)) lotsS=MarketInfo(Symbol(),MODE_MAXLOT);
      
      double SL1=0; 
      if(StopLoss>0)  SL1=MarketInfo(Symbol(),MODE_ASK)+MarketInfo(Symbol(),MODE_POINT)*StopLoss;
      SL1=NormalizeDouble(SL1,Digits);
      if(SLnTPMode==Client) SL1=0; 
      //double TP1=0;
      //if( riskreward &&rr2>0)
      
      //if(TP>0)  TP1=MarketInfo(Symbol(),MODE_ASK)+MarketInfo(Symbol(),MODE_POINT)*TP; 
         
      int ticket=OrderSend(NULL,OP_SELL,NormalizeDouble(lotsS*multi*1,2),Bid,3,SL1,0,"",magic);
   
   //return;
   
   }
   if(countS_M==1)
   {
      
      if(lotsS<MarketInfo(Symbol(),MODE_MINLOT)) lotsS=MarketInfo(Symbol(),MODE_MINLOT);
      if(lotsS>MarketInfo(Symbol(),MODE_MAXLOT)) lotsS=MarketInfo(Symbol(),MODE_MAXLOT);
      
      double SL1=0; 
      if(StopLoss>0)  SL1=MarketInfo(Symbol(),MODE_ASK)+MarketInfo(Symbol(),MODE_POINT)*StopLoss;
      SL1=NormalizeDouble(SL1,Digits);
      if(SLnTPMode==Client) SL1=0; 
      //double TP1=0;
      //if( riskreward &&rr2>0)
      
      //if(TP>0)  TP1=MarketInfo(Symbol(),MODE_ASK)+MarketInfo(Symbol(),MODE_POINT)*TP; 
         
      int ticket=OrderSend(NULL,OP_SELL,NormalizeDouble(lotsS*multi*multi,2),Bid,3,SL1,0,"",magic);
   
   //return;
   
   }
return;
}   

// open tp ----------------------------------------------------------------------------------
if(countB==3)
{
    
      
for(int i=0;i<OrdersTotal(); i++ ){
if(OrderSelect(i, SELECT_BY_POS,MODE_TRADES)==true){ 
if(OrderSymbol()==Symbol() )
{
if (OrderType()==OP_BUY  )
{
      double tp1=0;
      if( riskreward &&rr1>0)
      {                 
      tp1=OrderOpenPrice()+MarketInfo(Symbol(),MODE_POINT)*StopLoss*rr1;       
      }
      double tp2=0;
      if( riskreward &&rr2>0)
      {                 
      tp2=OrderOpenPrice()+MarketInfo(Symbol(),MODE_POINT)*StopLoss*rr2;       
      }      
      double tp3=0;
      if( riskreward &&rr3>0)
      {                 
      tp3=OrderOpenPrice()+MarketInfo(Symbol(),MODE_POINT)*StopLoss*rr3;       
      }  
   
   //if(SLnTPMode==Client) {tp1=0;tp2=0;tp3=0; }
   if(SLnTPMode==Server &&riskreward)
   {   
   if(OrderTicket()==ticker_b1 &&OrderTakeProfit()==0) bool res1=OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),NormalizeDouble(tp1,Digits),0,clrBlue);
   if(OrderTicket()==ticker_b2 &&OrderTakeProfit()==0) bool res2=OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),NormalizeDouble(tp2,Digits),0,clrBlue);
   if(OrderTicket()==ticker_b3 &&OrderTakeProfit()==0) bool res3=OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),NormalizeDouble(tp3,Digits),0,clrBlue);
   }
}
}}}

}
if(countS==3)
{
    
      
for(int i=0;i<OrdersTotal(); i++ ){
if(OrderSelect(i, SELECT_BY_POS,MODE_TRADES)==true){ 
if(OrderSymbol()==Symbol() )
{
if (OrderType()==OP_SELL  )
{
      double tp1=0;
      if( riskreward &&rr1>0)
      {                 
      tp1=OrderOpenPrice()-MarketInfo(Symbol(),MODE_POINT)*StopLoss*rr1;       
      }
      double tp2=0;
      if( riskreward &&rr2>0)
      {                 
      tp2=OrderOpenPrice()-MarketInfo(Symbol(),MODE_POINT)*StopLoss*rr2;       
      }      
      double tp3=0;
      if( riskreward &&rr3>0)
      {                 
      tp3=OrderOpenPrice()-MarketInfo(Symbol(),MODE_POINT)*StopLoss*rr3;       
      }  
   //if(SLnTPMode==Client) {tp1=0;tp2=0;tp3=0; }
   if(SLnTPMode==Server &&riskreward)
   {
   if(OrderTicket()==ticker_s1 &&OrderTakeProfit()==0) bool res1=OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),NormalizeDouble(tp1,Digits),0,clrBlue);
   if(OrderTicket()==ticker_s2 &&OrderTakeProfit()==0) bool res2=OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),NormalizeDouble(tp2,Digits),0,clrBlue);
   if(OrderTicket()==ticker_s3 &&OrderTakeProfit()==0) bool res3=OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),NormalizeDouble(tp3,Digits),0,clrBlue);
   }
}
}}}

}

// manage 2 ------------------------------------------------------------------------------------
if( countB==2 &&SLnTPMode==Server)
{
for(int i=0;i<OrdersTotal(); i++ ){
if(OrderSelect(i, SELECT_BY_POS,MODE_TRADES)==true){ 
if(OrderSymbol()==Symbol() )
{
if (OrderType()==OP_BUY &&breakeven )
{
   if(OrderTicket()==ticker_b1 &&OrderStopLoss()<OrderOpenPrice() &&Bid-OrderOpenPrice()>0 ) bool res1=OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice()+breakeven_*Point,OrderTakeProfit(),0,clrBlue);
   if(OrderTicket()==ticker_b2 &&OrderStopLoss()<OrderOpenPrice() &&Bid-OrderOpenPrice()>0 ) bool res2=OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice()+breakeven_*Point,OrderTakeProfit(),0,clrBlue);
}
}}}

}
if( countS==2)
{
for(int i=0;i<OrdersTotal(); i++ ){
if(OrderSelect(i, SELECT_BY_POS,MODE_TRADES)==true){ 
if(OrderSymbol()==Symbol() )
{
if (OrderType()==OP_SELL &&breakeven )
{
   if(OrderTicket()==ticker_s1 &&OrderStopLoss()>OrderOpenPrice() &&OrderOpenPrice()-Ask>0 ) bool res1=OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice()-breakeven_*Point,OrderTakeProfit(),0,clrBlue);
   if(OrderTicket()==ticker_s2 &&OrderStopLoss()>OrderOpenPrice() &&OrderOpenPrice()-Ask>0 ) bool res2=OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice()-breakeven_*Point,OrderTakeProfit(),0,clrBlue);
}
}}}

}

// manage 1 ------------------------------------------------------------------------------------
if( countB==1 &&SLnTPMode==Server)
{
for(int i=0;i<OrdersTotal(); i++ ){
if(OrderSelect(i, SELECT_BY_POS,MODE_TRADES)==true){ 
if(OrderSymbol()==Symbol() )
{
if (OrderType()==OP_BUY &&breakeven )
{
   
   double cc=OrderOpenPrice()+StopLoss*rr1*Point;
   cc=NormalizeDouble(cc,Digits);
   if(OrderTicket()==ticker_b1 &&OrderStopLoss()<cc &&Bid-cc>0 ) bool res1=OrderModify(OrderTicket(),OrderOpenPrice(),cc,OrderTakeProfit(),0,clrBlue);
   //if(OrderTicket()==ticker_b2 &&OrderStopLoss()<OrderOpenPrice() &&Bid-OrderOpenPrice()>0 ) bool res2=OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice(),OrderTakeProfit(),0,clrBlue);
}
}}}

}
if( countS==1)
{
for(int i=0;i<OrdersTotal(); i++ ){
if(OrderSelect(i, SELECT_BY_POS,MODE_TRADES)==true){ 
if(OrderSymbol()==Symbol() )
{
if (OrderType()==OP_SELL &&breakeven )
{
   
   double cc=OrderOpenPrice()-StopLoss*rr1*Point;
   cc=NormalizeDouble(cc,Digits);
   if(OrderTicket()==ticker_s1 &&OrderStopLoss()>cc &&cc-Ask>0 ) bool res1=OrderModify(OrderTicket(),OrderOpenPrice(),cc,OrderTakeProfit(),0,clrBlue);
   //if(OrderTicket()==ticker_s2 &&OrderStopLoss()>OrderOpenPrice() &&OrderOpenPrice()-Ask>0 ) bool res2=OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice(),OrderTakeProfit(),0,clrBlue);
}
}}}

}

/*
// breakevet ------------------------------------------------------------------------------------
for(int i=0;i<OrdersTotal(); i++ ){
if(OrderSelect(i, SELECT_BY_POS,MODE_TRADES)==true){ 
if(OrderSymbol()==Symbol() )
{
if (OrderType()==OP_BUY  )
{
      if(breakeven>0 &&OrderStopLoss()<OrderOpenPrice() &&Ask-OrderOpenPrice()>breakeven*Point )
      bool res1=OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice(),OrderTakeProfit(),0,clrMagenta);
       
}


if (OrderType()==OP_SELL )
{
      if(breakeven>0 &&OrderStopLoss()>OrderOpenPrice() &&OrderOpenPrice()-Bid>breakeven*Point )
      bool res1=OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice(),OrderTakeProfit(),0,clrMagenta);
}
}}}
*/
/*
   ObjectCreate ("klc2838962", OBJ_LABEL, 0, 0, 0);   
   ObjectSet    ("klc2838962", OBJPROP_CORNER, 3);
   ObjectSet    ("klc2838962", OBJPROP_XDISTANCE, 10);
   ObjectSet    ("klc2838962", OBJPROP_YDISTANCE, 10);
   ObjectSetText("klc2838962", "buy "+countB, 20, "Browallia New",Gold);
   */
OrderTest();   
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OrderTest()
  {
   if(!IsTesting()) return;
   if(CalculateCurrentOrders()!=0) return;
   if(Volume[0]>1) return;
   double MA[3];

   MA[0]=iMA(NULL,0,10,0,MODE_EMA,PRICE_CLOSE,0);
   MA[1]=iMA(NULL,0,20,0,MODE_EMA,PRICE_CLOSE,0);
   MA[2]=iMA(NULL,0,100,0,MODE_EMA,PRICE_CLOSE,0);

   if((MA[0]<MA[1]) && MA[0]>MA[2])
      int ticket=OrderSend(NULL,OP_BUY,MarketInfo(Symbol(),MODE_MINLOT),Ask,3,0,0,"",0);
  
   else   
   
   if((MA[0]>MA[1]) && MA[0]<MA[2])
      int ticket=OrderSend(NULL,OP_SELL,MarketInfo(Symbol(),MODE_MINLOT),Bid,3,0,0,"",0);
     
      
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void CloseAll_t(int ticket)
  {   
   //int ticket;
   if (OrdersTotal() == 0) return;
   for (int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if (OrderSelect (i, SELECT_BY_POS, MODE_TRADES) == true)
           {
           

         if (OrderType() == OP_BUY   &&OrderTicket()==ticket  &&OrderSymbol()==Symbol())
            {
             ticket = OrderClose (OrderTicket(), OrderLots(), MarketInfo (OrderSymbol(), MODE_BID), 3, CLR_NONE);
             
             
             if (ticket == -1) Print ("Error: ", GetLastError());
             if (ticket >   0) Print ("Position ", OrderTicket() ," closed");
            }
          if (OrderType() == OP_SELL   &&OrderTicket()==ticket  &&OrderSymbol()==Symbol())
            {
             ticket = OrderClose (OrderTicket(), OrderLots(), MarketInfo (OrderSymbol(), MODE_ASK), 3, CLR_NONE);
             
             
             if (ticket == -1) Print ("Error: ",  GetLastError());
             if (ticket >   0) Print ("Position ", OrderTicket() ," closed");
            }                      
         }
      }   
   return;
  } 
//+------------------------------------------------------------------+
