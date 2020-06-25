USE [TRM]
GO

/****** Object:  View [dbo].[V_IRM_Report_RequirementsListDelivery]    Script Date: 23-06-2020 1:25:54 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author		: Dawid Bolewski
-- Create Date	: 2020-06-23
-- Description	:  detailed statuses with [Delivery required by] date 
-- Report query: 
-- SELECT DISTINCT [RequirementID] AS idrec ,[RequirementMaterialID] ,[RequirementID] ,[Customer Order] ,[WO Status] ,[Site Code] ,[ALU Code] ,[ALU Description] ,[QTY Required] ,[Order Summary] ,[Status] ,[QTY] ,[ETA] ,[Actual IRM Order Date] ,[RFS Week] ,[WO Priority] ,[PL] ,[PM] FROM [V_IRM_Report_RequirementsList] WITH(NOLOCK) WHERE ([Access Function] IN (SELECT [Access Function] FROM fn_IRM_GetUserStatus(4678)) OR [Access Function] = 'Not Specified')
-- =============================================
ALTER VIEW [dbo].[V_IRM_Report_RequirementsListDelivery]
AS
SELECT
	 REM.[RequirementMaterialID]
	,REM.[RequirementID]
	,REQ.[Customer Order]
	,REQ.[PIF Status] AS [WO Status]
	,REQ.[SiteID]
	,REQ.[Site Code]
	,REM.[ALUcodeID]
	,AC.[ALU Code]
	,AC.[ALU Description]
	,REM.[QTY Required]
	,STUFF((
		   SELECT ' QTY Ordered=' + ISNULL(CAST(OM.[QTY Ordered] AS NVARCHAR(10)),0)
		   + ',QTY Delivered='
		+ ISNULL(CAST((
			SELECT SUM([QTY Assigned to Order])
			FROM IRM_Deliveries_To_Order_Materials TOM
			JOIN IRM_Deliveries_Materials DM ON DM.DeliveryMaterialID = TOM.DeliveryMaterialID
			WHERE TOM.OrderMaterialID = OM.OrderMaterialID) AS NVARCHAR(10)),0)
		    + ',Order Type=' + O.[Order Type]
			+ ',OrderID=<a href=''javascript:void(0)''
			onclick=''editForm(this, "editOrder","Edit Order", "Orders", "Orders", 1100, 500, '
			+ CAST(O.[OrderID] AS NVARCHAR(10)) + ')''>'
			+ CAST(O.[OrderID] AS NVARCHAR(10)) + '</a>'
			+ ISNULL(', ETA=' + CONVERT(NVARCHAR(10), O.[ETA], 121), '') + '<br/>'
		   FROM [IRM_Orders_Materials] OM
		   INNER JOIN [IRM_Orders] O ON OM.[OrderID] = O.[OrderID]
		   INNER JOIN [IRM_Materials] m ON OM.[MaterialID] = m.[MaterialID]
		   WHERE OM.[RequirementMaterialID] = REM.[RequirementMaterialID]
		   FOR XML PATH(''),TYPE).value('(./text())[1]','NVARCHAR(MAX)'), 1, 1, '') AS [Order Summary]
	 ,STUFF((
		   SELECT '<br style="mso-data-placement:same-cell;" />'
		   +'QTY Ordered=' + ISNULL(CAST(OM.[QTY Ordered] AS NVARCHAR(10)),0)
		   +',Order Type=' + O.[Order Type]
		   +',OrderID=' + CAST(O.[OrderID] AS NVARCHAR(10))+ISNULL(', ETA=' + CONVERT(NVARCHAR(10), O.[ETA], 121), '')
		   FROM [IRM_Orders_Materials] OM
		   INNER JOIN [IRM_Orders] O ON OM.[OrderID] = O.[OrderID]
		   INNER JOIN [IRM_Materials] m ON OM.[MaterialID] = m.[MaterialID]
		   WHERE OM.[RequirementMaterialID] = REM.[RequirementMaterialID]
		   FOR XML PATH(''),TYPE).value('(./text())[1]','NVARCHAR(MAX)'), 1, 44, '') AS [OrderSummaryWithoutLink]
	,CASE WHEN FST.[Status] IS NOT NULL THEN FST.[Status] ELSE REQ.[Status] END AS [Status]
	,CASE WHEN FST.[Status] IS NOT NULL THEN FST.[QTY] ELSE REM.[QTY Required] END AS [QTY]
	,REQ.[ETA]
	,DLVRS.[Delivery required by]
	,REQ.[Actual IRM Order Date]
	,REQ.[RFS Week]
	,REQ.[PIF Priority] AS [WO Priority]
	,REQ.[PL PIF] AS [PL]
	,REQ.[PM PIF] AS [PM]
	,REQ.[Access function]
	,REQ.[Created DateTime]
	,CASE WHEN [REQ].[Status] IN ('On Site','Released') AND [REQ].[PIF Status] IN ('COMPLETED','CANCELLED')
		THEN 0 ELSE 1 END AS IsActive
	,O.[Order Type]
FROM [IRM_Requirements_Materials] REM WITH (NOLOCK)
INNER JOIN [V_IRM_Requirements] REQ WITH (NOLOCK) ON REM.[RequirementID] = REQ.[RequirementID]
INNER JOIN [IRM_ALUCodes] AC WITH (NOLOCK) ON REM.[ALUcodeID] = AC.[ALUcodeID]
INNER JOIN [V_IRM_Requirements_Materials_Status] RMS WITH (NOLOCK) ON REM.[RequirementMaterialID] = RMS.[RequirementMaterialID]
LEFT JOIN [dbo].[IRM_Orders_Materials] OM WITH (NOLOCK) ON OM.[RequirementMaterialID] = REM.[RequirementMaterialID]
LEFT JOIN [dbo].[IRM_Orders] O WITH (NOLOCK) ON O.[OrderID] = OM.[OrderID]
LEFT JOIN [dbo].[V_IRM_Requirements_Materials_SingleStatus] FST WITH (NOLOCK) ON FST.RequirementID = REM.RequirementID AND FST.RequirementMaterialID = REM.RequirementMaterialID
LEFT JOIN (
	SELECT [IRS].[RequirementID]	
		,STUFF((SELECT DISTINCT ','+CONVERT(NVARCHAR(10), ISD.[Delivery required by], 20)
			FROM [dbo].[V_IRM_Shipments_Delivery] ISD
			WHERE ISD.RequirementID = IRS.RequirementID AND ISD.[ALU Code] = IRS.[ALU Code]
			FOR XML PATH('')),1,1,'') AS [Delivery required by]
		,IRS.[Delivery required by]
		,[ALU Code]
		,SUM([QTY Shipped]) AS [QTY Shipped]
	FROM [dbo].[V_IRM_Shipments_Delivery] IRS
	--where irs.RequirementID = 425
	GROUP BY RequirementID, [ALU Code] 
) DLVRS ON REQ.RequirementID = DLVRS.[RequirementID] AND AC.[ALU Code] = DLVRS.[ALU Code] AND FST.[QTY] = DLVRS.[QTY Shipped]
GO


