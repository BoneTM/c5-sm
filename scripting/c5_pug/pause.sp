Handle g_PauseTimer = INVALID_HANDLE;

void ResetPauseCount()
{
  g_PauseCount[CS_TEAM_T] = g_PauseCountLimitCvar.IntValue;
  g_PauseCount[CS_TEAM_CT] = g_PauseCountLimitCvar.IntValue;
}

void StartPauseCountDown()
{
  DataPack pack;
  g_PauseTimer = CreateDataTimer(1.0, Timer_PauseCountDown, pack, TIMER_REPEAT);
  pack.WriteCell(g_PauseTimeCvar.IntValue);
}

public Action Timer_PauseCountDown(Handle timer, DataPack pack)
{
  pack.Reset();
  int timeLeft = pack.ReadCell();
  PrintHintTextToAll("暂停倒计时\n剩余: %d", timeLeft);
  pack.Reset();
  pack.WriteCell(--timeLeft);
  
  if (timeLeft <= 0)
  {
    Unpause();
    PrintHintTextToAll("倒计时结束\n继续冲冲冲!");
    return Plugin_Stop;
  }

  return Plugin_Continue;
}

void StopPauseCountDown()
{
  if (g_PauseTimer != INVALID_HANDLE)
  {
    KillTimer(g_PauseTimer);
  }
}