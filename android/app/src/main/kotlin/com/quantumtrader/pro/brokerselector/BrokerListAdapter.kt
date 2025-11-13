package com.quantumtrader.pro.brokerselector

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.card.MaterialCardView
import com.google.android.material.chip.Chip
import com.quantumtrader.pro.R

/**
 * RecyclerView adapter for displaying broker list.
 */
class BrokerListAdapter(
    private val onBrokerClick: (Broker) -> Unit
) : ListAdapter<Broker, BrokerListAdapter.BrokerViewHolder>(BrokerDiffCallback()) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): BrokerViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_broker, parent, false)
        return BrokerViewHolder(view, onBrokerClick)
    }

    override fun onBindViewHolder(holder: BrokerViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    class BrokerViewHolder(
        itemView: View,
        private val onBrokerClick: (Broker) -> Unit
    ) : RecyclerView.ViewHolder(itemView) {

        private val brokerCard: MaterialCardView = itemView.findViewById(R.id.brokerCard)
        private val brokerIcon: ImageView = itemView.findViewById(R.id.brokerIcon)
        private val brokerName: TextView = itemView.findViewById(R.id.brokerName)
        private val brokerSubtitle: TextView = itemView.findViewById(R.id.brokerSubtitle)
        private val brokerDescription: TextView = itemView.findViewById(R.id.brokerDescription)
        private val platformBadge: Chip = itemView.findViewById(R.id.platformBadge)
        private val demoBadge: Chip = itemView.findViewById(R.id.demoBadge)

        fun bind(broker: Broker) {
            brokerName.text = broker.getDisplayName()
            brokerSubtitle.text = broker.getSubtitle()

            // Description
            if (broker.description != null) {
                brokerDescription.visibility = View.VISIBLE
                brokerDescription.text = broker.description
            } else {
                brokerDescription.visibility = View.GONE
            }

            // Platform badge
            platformBadge.text = broker.platform

            // Demo badge
            demoBadge.visibility = if (broker.demo) View.VISIBLE else View.GONE

            // Click listener
            brokerCard.setOnClickListener {
                onBrokerClick(broker)
            }

            // Accessibility
            itemView.contentDescription = buildString {
                append(broker.name)
                if (broker.demo) append(" Demo")
                append(", ${broker.platform} platform, server ${broker.server}")
            }
        }
    }

    /**
     * DiffUtil callback for efficient list updates.
     */
    private class BrokerDiffCallback : DiffUtil.ItemCallback<Broker>() {
        override fun areItemsTheSame(oldItem: Broker, newItem: Broker): Boolean {
            return oldItem.server == newItem.server
        }

        override fun areContentsTheSame(oldItem: Broker, newItem: Broker): Boolean {
            return oldItem == newItem
        }
    }
}

/**
 * Filter for broker list based on search query and platform.
 */
class BrokerFilter {
    companion object {
        /**
         * Filter brokers by search query and platform.
         *
         * @param brokers The full list of brokers
         * @param query Search query (searches name and server)
         * @param platform Platform filter ("MT4", "MT5", or null for all)
         * @param demoOnly Show only demo accounts
         * @return Filtered list
         */
        fun filter(
            brokers: List<Broker>,
            query: String? = null,
            platform: String? = null,
            demoOnly: Boolean = false
        ): List<Broker> {
            var filtered = brokers

            // Platform filter
            if (platform != null) {
                filtered = filtered.filter { it.platform == platform }
            }

            // Demo filter
            if (demoOnly) {
                filtered = filtered.filter { it.demo }
            }

            // Search query
            if (!query.isNullOrBlank()) {
                val lowerQuery = query.lowercase()
                filtered = filtered.filter {
                    it.name.lowercase().contains(lowerQuery) ||
                    it.server.lowercase().contains(lowerQuery) ||
                    it.description?.lowercase()?.contains(lowerQuery) == true
                }
            }

            return filtered
        }
    }
}
