#include "transcode_data.h"

<%
  require "euckr-tbl"
  require "cp949-tbl"
%>

<%= transcode_tblgen "UTF-8", "EUC-KR", [["{00-7f}", :nomap], *UCS_TO_EUCKR_TBL] %>
<%= transcode_tblgen "EUC-KR", "UTF-8", [["{00-7f}", :nomap], *EUCKR_TO_UCS_TBL] %>
<%= transcode_tblgen "UTF-8", "CP949", [["{00-7f}", :nomap], *UCS_TO_CP949_TBL] %>
<%= transcode_tblgen "CP949", "UTF-8", [["{00-7f}", :nomap], *CP949_TO_UCS_TBL] %>

void
Init_korean(void)
{
<%= transcode_register_code %>
}
