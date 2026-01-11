class PlannedPlacementsController < ApplicationController
  def unassign
    placement = PlannedPlacement.find(params[:id])
    article   = placement.article

    placement.destroy!

    # Recalculate article planned / part_planned flags
    article.sync_planned_flags!

    redirect_back(
      fallback_location: aisle_sections_path(placement.aisle),
      notice: "Placement unassigned"
    )
  end
end
