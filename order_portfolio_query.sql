/*
Order Portfolio (Oracle Fusion BI SQL - old Oracle join syntax)

Requested output columns:
INSTANCE, DOCUMENT_NUM, DOCUMENT_STATUS_CODE, LINE_NUMBER, LINE_TYPE_LOOKUP_CODE,
ITEM_SEGMENT1, LINE_STATUS_CODE, SHIP_TO_LOCATION, ORDERED_QUANTITY,
REQUEST_ARRIVAL_DATE (from REQUEST_SHIP_DATE with conditional formatting), ORDER_DATE,
MARKET_CODE, SHIP_FROM_ORGANIZATION, BILL_TO_LOCATION, COUNTRYCODE,
FORECAST_PROFILE_CODE, ITEM_PRODUCT_LINE, REQUEST_RECEPTION_DATE,
SCHEDULE_RECEPTION_DATE, COMMERCIAL_OFFER.

Important mapping notes:
- MARKET_CODE / FORECAST_PROFILE_CODE / COMMERCIAL_OFFER are sourced from
  DOO_FULFILL_LINES_EFF_VL attribute columns. Update context and attribute mapping
  according to your tenant's EFF configuration.
- ITEM_PRODUCT_LINE is sourced from item category assignment (EGP_ITEM_CATEGORIES -> EGP_CATEGORIES_B).
  Optionally restrict by category set using :P_PRODUCT_LINE_CATEGORY_SET_ID.
*/

SELECT
    bu.BU_NAME                                                          INSTANCE,
    h.ORDER_NUMBER                                                      DOCUMENT_NUM,
    h.STATUS_CODE                                                       DOCUMENT_STATUS_CODE,
    fl.FULFILL_LINE_NUMBER                                              LINE_NUMBER,
    fl.LINE_TYPE_CODE                                                   LINE_TYPE_LOOKUP_CODE,
    itm.ITEM_NUMBER                                                     ITEM_SEGMENT1,
    fl.STATUS_CODE                                                      LINE_STATUS_CODE,
    ship_su.LOCATION                                                    SHIP_TO_LOCATION,
    fl.ORDERED_QTY                                                      ORDERED_QUANTITY,
    CASE
        WHEN bu.BU_NAME = 'FOP EUR' THEN
            TO_CHAR(
                FROM_TZ(CAST(fl.REQUEST_SHIP_DATE AS TIMESTAMP), SESSIONTIMEZONE),
                'YYYY-MM-DD"T"HH24:MI:SS TZH:TZM'
            )
        ELSE
            TO_CHAR(fl.REQUEST_SHIP_DATE, 'DD-MM-YYYY')
    END                                                                 REQUEST_ARRIVAL_DATE,
    fl.CREATION_DATE                                                    ORDER_DATE,
    eff_mkt.ATTRIBUTE_CHAR1                                             MARKET_CODE,
    org.ORGANIZATION_CODE || ' - ' || org.ORGANIZATION_NAME            SHIP_FROM_ORGANIZATION,
    bill_su.LOCATION                                                    BILL_TO_LOCATION,
    bill_loc.COUNTRY                                                    COUNTRYCODE,
    eff_forecast.ATTRIBUTE_CHAR1                                        FORECAST_PROFILE_CODE,
    cat.CATEGORY_CODE                                                   ITEM_PRODUCT_LINE,
    fl.REQUEST_ARRIVAL_DATE                                             REQUEST_RECEPTION_DATE,
    fl.SCHEDULE_ARRIVAL_DATE                                            SCHEDULE_RECEPTION_DATE,
    eff_offer.ATTRIBUTE_CHAR1                                           COMMERCIAL_OFFER

FROM
    DOO_HEADERS_ALL                 h,
    DOO_LINES_ALL                   l,
    DOO_FULFILL_LINES_ALL           fl,
    FUN_ALL_BUSINESS_UNITS_V        bu,
    EGP_SYSTEM_ITEMS_B              itm,
    INV_ORGANIZATION_DEFINITIONS_V  org,
    HZ_CUST_SITE_USES_ALL           ship_su,
    HZ_CUST_SITE_USES_ALL           bill_su,
    HZ_CUST_ACCT_SITES_ALL          bill_cas,
    HZ_PARTY_SITES                  bill_ps,
    HZ_LOCATIONS                    bill_loc,
    DOO_FULFILL_LINES_EFF_VL        eff_mkt,
    DOO_FULFILL_LINES_EFF_VL        eff_forecast,
    DOO_FULFILL_LINES_EFF_VL        eff_offer,
    EGP_ITEM_CATEGORIES             ic,
    EGP_CATEGORIES_B                cat

WHERE
        h.HEADER_ID = l.HEADER_ID
    AND l.LINE_ID = fl.LINE_ID
    AND h.ORG_ID = bu.BU_ID
    AND fl.FULFILL_ORG_ID = org.ORGANIZATION_ID
    AND fl.INVENTORY_ITEM_ID = itm.INVENTORY_ITEM_ID(+)
    AND fl.INVENTORY_ORGANIZATION_ID = itm.ORGANIZATION_ID(+)

    AND fl.SHIP_TO_SITE_USE_ID = ship_su.SITE_USE_ID(+)
    AND fl.BILL_TO_SITE_USE_ID = bill_su.SITE_USE_ID(+)

    AND bill_su.CUST_ACCT_SITE_ID = bill_cas.CUST_ACCT_SITE_ID(+)
    AND bill_cas.PARTY_SITE_ID = bill_ps.PARTY_SITE_ID(+)
    AND bill_ps.LOCATION_ID = bill_loc.LOCATION_ID(+)

    AND fl.FULFILL_LINE_ID = eff_mkt.FULFILL_LINE_ID(+)
    AND eff_mkt.CONTEXT_CODE(+) = :P_MARKET_CONTEXT_CODE

    AND fl.FULFILL_LINE_ID = eff_forecast.FULFILL_LINE_ID(+)
    AND eff_forecast.CONTEXT_CODE(+) = :P_FORECAST_CONTEXT_CODE

    AND fl.FULFILL_LINE_ID = eff_offer.FULFILL_LINE_ID(+)
    AND eff_offer.CONTEXT_CODE(+) = :P_OFFER_CONTEXT_CODE

    AND fl.INVENTORY_ITEM_ID = ic.INVENTORY_ITEM_ID(+)
    AND fl.INVENTORY_ORGANIZATION_ID = ic.ORGANIZATION_ID(+)
    AND ic.CATEGORY_ID = cat.CATEGORY_ID(+)
    AND ( :P_PRODUCT_LINE_CATEGORY_SET_ID IS NULL
          OR ic.CATEGORY_SET_ID = :P_PRODUCT_LINE_CATEGORY_SET_ID )

    AND ( :P_ORDER_NUMBER IS NULL OR h.ORDER_NUMBER = :P_ORDER_NUMBER )
    AND ( :P_BU_NAME IS NULL OR bu.BU_NAME = :P_BU_NAME )
    AND ( :P_FROM_CREATION_DATE IS NULL OR fl.CREATION_DATE >= :P_FROM_CREATION_DATE )
    AND ( :P_TO_CREATION_DATE IS NULL OR fl.CREATION_DATE < :P_TO_CREATION_DATE + 1 )

ORDER BY
    h.ORDER_NUMBER,
    fl.FULFILL_LINE_NUMBER;
